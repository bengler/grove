# encoding: utf-8
require_relative './post/document_validator'
require_relative '../cache_key'

class Post < ActiveRecord::Base

  class CanonicalPathConflict < StandardError; end

  SORTABLE_FIELDS = %w(
    id
    created_at
    updated_at
    document_updated_at
    external_document_updated_at
    external_document
  )

  # Optimistic locking via version column
  self.locking_column = 'version'

  # If set to true, observers won't notify about this record
  attr_accessor :skip_river_notification_on_save

  include TsVectorTags
  include CacheKey

  has_and_belongs_to_many :locations, :uniq => true,
    :after_add => :increment_unread_counts,
    :after_remove => :decrement_unread_counts

  validates_presence_of :realm

  validate :canonical_path_must_be_valid
  validates_with DocumentValidator
  validates_format_of :klass, :with => /\Apost(\.|\z)/
  # TODO: Remove '.' from allowed characters in external_id when parlor
  # has been updated
  validates_format_of :external_id,
    :with => /\A[a-zA-Z_-]/,
    :if => lambda { |record| !record.external_id.nil? },
    :message => "must start with a non-digit character"
  before_validation :assign_realm, :set_default_klass

  before_save :ensure_timestamps
  before_save :revert_unmodified_values
  before_save :update_conflicted
  before_save :attach_canonical_path
  before_destroy :attach_canonical_path
  before_save :update_readmarks_according_to_deleted_status
  before_save :update_external_id_according_to_deleted_status
  after_update :invalidate_cache
  before_destroy :invalidate_cache

  default_scope do
    where(deleted: false)
  end

  serialize :document
  serialize :external_document
  serialize :protected
  serialize :sensitive

  scope :by_path, ->(path) {
    conditions = Pebbles::Path.to_conditions(path)
    if conditions.any?
      locations = Location.arel_table
      locations_posts = Arel::Table.new('locations_posts')
      subquery = locations_posts.project(:post_id).
        join(locations).on(locations[:id].eq(locations_posts[:location_id]))
      conditions.each do |column, value|
        if value.respond_to?(:to_ary)
          subquery.where(locations[column].in(value))
        else
          subquery.where(locations[column].eq(value))
        end
      end
      where(Post.arel_table[:id].in(subquery))
    else
      nil
    end
  }

  scope :by_uid, lambda { |uid|
    _klass, _path, _oid = Pebbles::Uid.parse(uid)
    scope = by_path(_path)
    scope = scope.where("klass in (?)", _klass.split('|')) unless _klass == '*'
    scope = scope.where("posts.id = ?", _oid.to_i) unless _oid.nil? || _oid == '' || _oid == '*'
    scope
  }

  scope :by_occurrence, lambda { |label|
    joins(:occurrence_entries).readonly(false).where(occurrence_entries: {label: label})
  }

  scope :occurs_after, lambda { |timestamp|
    where("occurrence_entries.at >= ?", timestamp.utc)
  }

  scope :occurs_before, lambda { |timestamp|
    where("occurrence_entries.at < ?", timestamp.utc)
  }

  # FIXME: In order to support the "deleted" filter, queries must be performed with default scope disabled.
  scope :filtered_by, lambda { |filters|
    scope = all
    scope = scope.where(deleted: false) unless filters['deleted'] == 'include'
    if (since = filters['since'])
      since = Time.parse(since) unless since.is_a?(Time) or since.is_a?(DateTime)
      since = Time.at(since.to_f.floor)  # Truncate to nearest second
      scope = scope.where("(posts.created_at >= ? or posts.updated_at >= ?)", since, since)
    end
    scope = scope.where("posts.created_at > ?", Time.parse(filters['created_after'])) if filters['created_after']
    scope = scope.where("posts.created_at < ?", Time.parse(filters['created_before'])) if filters['created_before']
    scope = scope.where(:realm => filters['realm']) if filters['realm']
    scope = scope.where(:klass => filters['klass'].split(',').map(&:strip)) if filters['klass']
    scope = scope.where(:external_id => filters['external_id'].split(',').map(&:strip)) if filters['external_id']
    if filters['tags']
      # Use a common tags scope if filter is an array or comma separated list
      if filters['tags'].is_a?(Array) || (filters['tags'] =~ /\,/)
        scope = scope.with_tags(filters['tags'])
      else
        scope = scope.with_tags_query(filters['tags'])
      end
    end
    scope = scope.where("published") unless ['include', 'only'].include?(filters['unpublished'])
    scope = scope.where("published is false") if filters['unpublished'] == 'only'
    scope = scope.where(:created_by => filters['created_by']) if filters['created_by']
    scope
  }

  # Scope search to return posts visible to an identity.
  def self.with_restrictions(identity)
    if identity.nil? or not identity.respond_to?(:id)
      where({restricted: false, deleted: false, published: true})
    else
      if identity.god
        where(realm: identity.realm)
      else
        joins(:locations).
          joins("left outer join group_locations on group_locations.location_id = locations.id").
          joins("left outer join group_memberships on group_memberships.group_id = group_locations.group_id and group_memberships.identity_id = #{identity.id}").
          where(['(not restricted and not deleted and published) or created_by = ? or group_memberships.identity_id = ?', identity.id, identity.id])
      end
    end
  end

  # Scope search to return posts editable by an identity.
  def self.editable_by(identity)
    if identity.nil? or not identity.respond_to?(:id)
      where('false') # shortcuts any other chained scopes
    else
      if identity.god
        where(realm: identity.realm)
      else
        where('created_by = :id or (posts.id in (
          select post_id
          from locations_posts
          join group_locations gl on gl.location_id = locations_posts.location_id
          join group_memberships gm on gm.group_id = gl.group_id
          where gm.identity_id = :id))', id: identity.id)
      end
    end
  end


  # Is this a hash?
  def self.hashlike?(value)
    value.is_a?(Hash) || (value.respond_to?(:to_h) && !value.is_a?(Array)) && !value.nil?
  end

  def attributes_for_export
    extras = {
      'paths' => paths.to_a,
      'uid' => uid
    }
    attributes.update('document' => merged_document).merge(extras)
  end

  # TODO: This method does not respect access-groups!? This is not a problem since we currently avoid
  # going this route.
  def visible_to?(identity)
    return true if !restricted && !deleted && published
    return false if nobody?(identity)
    return true if identity.god and identity.realm == self.realm
    identity.id == created_by
  end

  def nobody?(identity)
    !identity || !identity.respond_to?(:id)
  end

  def may_be_managed_by?(identity)
    new_record? || editable_by?(identity)
  end

  # not to be confused with the scope Post.editable_by(identity)
  def editable_by?(identity)
    return false if nobody?(identity)
    return true if (identity.god && identity.realm == self.realm)
    return true if identity.id == created_by
    self.locations.each do |location|
      return true if location.accessible_by?(identity.id)
    end
    return false
  end

  def external_document=(value)
    if value and not self.class.hashlike?(value)
      raise ArgumentError, "Document must be hash-like"
    end
    value = normalize_document(value)
    unless documents_equal?(value, self.external_document)
      write_attribute(:external_document, value)
      self.external_document_updated_at = Time.now
    end
  end

  def document=(value)
    if value and not self.class.hashlike?(value)
      raise ArgumentError, "Document must be hash-like"
    end
    value = normalize_document(value)
    if self.external_document
      value.reject! do |k, v|
        self.external_document[k] == v
      end
    end
    unless documents_equal?(value, self.document)
      write_attribute(:document, value)
      self.document_updated_at = Time.now
    end
  end

  # Override getters on serialized attributes with dup so the
  # attributes become dirty when we use the old value on the setter
  def external_document
    read_attribute(:external_document).try(:dup) || {}
  end

  def document
    read_attribute(:document).try(:dup) || {}
  end

  def protected
    read_attribute(:protected).try(:dup) || {}
  end

  def sensitive
    read_attribute(:sensitive).try(:dup) || {}
  end

  def merged_document(options = {})
    doc = HashWithIndifferentAccess.new
    doc.merge!(self.external_document.symbolize_keys) if self.external_document
    doc.merge!(self.document.symbolize_keys) if self.document
    if options[:include_occurrences] != false
      doc.merge!(occurrences: self.occurrences) if self.occurrences.present?
    end
    doc
  end

  def uid
    "#{klass}:#{canonical_path}$#{id}"
  end

  def uid=(value)
    self.klass, self.canonical_path, _oid = Pebbles::Uid.parse(value)

    unless _oid.nil? || _oid == "#{self.id}"
      raise ArgumentError, "Do not assign oid. It is managed by the model. (omit '...$#{_oid}' from uid)"
    end
  end

  def self.find_by_uid(uid)
    return nil unless Pebbles::Uid.oid(uid)
    self.by_uid(uid).first
  end

  def self.find_by_external_id_and_uid(external_id, provided_uid)
    return nil if external_id.nil?

    uid = Pebbles::Uid.new(provided_uid)
    post = self.where(:realm => uid.realm, :external_id => external_id).first
    if post && post.canonical_path != uid.path
      fail CanonicalPathConflict.new(post.uid)
    end
    post
  end

  # Accepts an array of `Pebbles::Uid.cache_key(uid)`s
  def self.cached_find_all_by_uid(cache_keys)
    result =  Hash[
      $memcached.get_multi(cache_keys.map {|key| CacheKey.wrap(key) }).map do |key, value|
        post = Post.instantiate(Yajl::Parser.parse(value))
        post.readonly!
        [CacheKey.unwrap(key), post]
      end
    ]

    (cache_keys-result.keys).each do |key|
      post = Post.find_by_uid(key)
      if post
        $memcached.set(post.cache_key, post.attributes.to_json) if post
        post = Post.instantiate(Yajl::Parser.parse(post.attributes.to_json))
      end
      result[key] = post
    end
    cache_keys.map {|key| result[key]}
  end

  def add_path!(path)
    self.paths << path
    self.save!
  end

  def remove_path!(path)
    self.paths.delete path
    self.save!
  end

  # Add an occurrence without having to save the post.
  # This is to avoid race conditions
  def add_occurrences!(event, at = [])
    Array(at).each do |time|
      OccurrenceEntry.create!(:post_id => id, :label => event, :at => time)
    end
  end

  def remove_occurrences!(event)
    OccurrenceEntry.where(:post_id => id, :label => event).destroy_all
  end

  def replace_occurrences!(event, at = [])
    remove_occurrences!(event)
    add_occurrences!(event, at)
  end

  private

  def invalidate_cache
    $memcached.delete(cache_key)
  end

  def assign_realm
    self.realm = self.canonical_path[/^[^\.]*/] if self.canonical_path
  end

  # Ensures that the post is attached to its canonical path
  def attach_canonical_path
    self.paths |= [self.canonical_path]
  end

  def canonical_path_must_be_valid
    unless Pebbles::Uid.valid_path?(self.canonical_path)
      error.add :base, "#{self.canonical_path.inspect} is an invalid path."
    end
  end

  def set_default_klass
    self.klass ||= "post"
  end

  def increment_unread_counts(location)
    Readmark.post_added(location.path.to_s, self.id) unless self.deleted?
  end

  def decrement_unread_counts(location)
    Readmark.post_removed(location.path.to_s, self.id) unless self.deleted?
  end

  def revert_unmodified_values
    # When updating a Post that has an external_document, make sure only the actual *changed* (overridden)
    # fields are kept in the `document` hash.
    return if document.nil? or external_document.nil?
    document.reject! { |key, value| external_document[key] == value }
  end

  def update_conflicted
    return if document.nil? or external_document.nil?
    overridden_fields = external_document.keys & document.keys
    self.conflicted = (self.external_document_updated_at > self.document_updated_at and overridden_fields.any?)
    true
  end

  def update_readmarks_according_to_deleted_status
    if self.deleted_changed?
      # We are using the locations relation directly to make sure we are not
      # picking up any unsynced changes that may have been applied to the
      # paths attribute.
      paths = self.locations.map { |location| location.path.to_s }
      if self.deleted
        paths.each { |path| Readmark.post_removed(path, self.id)}
      else
        paths.each { |path| Readmark.post_added(path, self.id)}
      end
    end
  end

  def update_external_id_according_to_deleted_status
    # A deleted post should not lock its external_id but we
    # archive it to post.document in order to make forensics easier.
    if self.deleted_changed?
      if self.deleted && self.external_id != nil
        doc = self.document || {} # TODO: never have posts with nil document
        doc.merge!('external_id' => self.external_id)
        self.document = doc
        self.external_id = nil
      end
    end
  end

  private

    # Normalize a document.
    def normalize_document(document)
      document = (document.try(:dup) || {}).stringify_keys
      HashWithIndifferentAccess[*document.entries.flat_map { |key, value|
        value = normalize_document(value) if self.class.hashlike?(value)
        [key, value]
      }]
    end

    # Are two documents identical?
    def documents_equal?(a, b)
      normalize_document(a) == normalize_document(b)
    end

    def ensure_timestamps
      self.document_updated_at ||= Time.now
      self.external_document_updated_at ||= Time.now
    end

end
