# encoding: utf-8
require_relative './post/document_validator'
require_relative '../cache_key'

class Post < ActiveRecord::Base
  class CanonicalPathConflict < StandardError; end

  include TsVectorTags
  include CacheKey

  has_and_belongs_to_many :locations, :uniq => true,
    :after_add => :increment_unread_counts,
    :after_remove => :decrement_unread_counts

  validates_presence_of :realm

  validate :canonical_path_must_be_valid
  validates_with DocumentValidator
  validates_format_of :klass, :with => /^post(\.|$)/
  # TODO: Remove '.' from allowed characters in external_id when parlor 
  # has been updated
  validates_format_of :external_id,
    :with => /^[a-zA-Z_-]/,
    :if => lambda { |record| !record.external_id.nil? },
    :message => "must start with a non-digit character"
  before_validation :assign_realm, :set_default_klass

  before_save :revert_unmodified_values
  before_save :update_conflicted
  before_save :sanitize
  before_save :attach_canonical_path
  before_save :update_readmarks_according_to_deleted_status
  before_save :update_external_id_according_to_deleted_status
  after_update :invalidate_cache
  before_destroy :invalidate_cache

  default_scope where("not deleted")

  serialize :document
  serialize :external_document

  scope :by_path, lambda { |path|
    select("distinct posts.*").joins(:locations).where(:locations => Pebbles::Path.to_conditions(path)) unless path == '*'
  }

  scope :by_uid, lambda { |uid|
    _klass, _path, _oid = Pebbles::Uid.parse(uid)
    scope = by_path(_path)
    scope = scope.where("klass = ?", _klass) unless _klass == '*'
    scope = scope.where("posts.id = ?", _oid.to_i) unless _oid.nil? || _oid == '' || _oid == '*'
    scope
  }

  scope :by_occurrence, lambda { |label|
    select('posts.*').select('occurrence_entries.at').joins(:occurrence_entries).where(:occurrence_entries => {:label => label})
  }

  scope :occurs_after, lambda { |timestamp|
    where("occurrence_entries.at >= ?", timestamp.utc)
  }

  scope :occurs_before, lambda { |timestamp|
    where("occurrence_entries.at < ?", timestamp.utc)
  }

  scope :filtered_by, lambda { |filters|
    scope = relation
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
    scope = scope.where(:created_by => filters['created_by']) if filters['created_by']
    scope
  }

  scope :with_restrictions, lambda { |identity|
    scope = relation
    if !identity || !identity.respond_to?(:id)
      scope = scope.where(:restricted => false)
    elsif !identity.god
      scope = scope.
        joins(:locations).
        joins("left outer join group_locations on group_locations.location_id = locations.id").
        joins("left outer join group_memberships on group_memberships.group_id = group_locations.group_id and group_memberships.identity_id = #{identity.id}").
        where(['not restricted or created_by = ? or group_memberships.identity_id = ?', identity.id, identity.id])
    end
    scope
  }

  def attributes_for_export
    attributes.update('document' => merged_document).merge('paths' => paths.to_a, 'uid' => uid)
  end

  def visible_to?(identity)
    return true unless restricted
    return false if nobody?(identity)
    return identity.god || identity.id == created_by
  end

  def nobody?(identity)
    !identity || !identity.respond_to?(:id)
  end

  def editable_by?(identity)
    return false if nobody?(identity)
    return identity.god || identity.id == created_by
  end

  def may_be_managed_by?(identity)
    new_record? || editable_by?(identity)
  end

  def external_document=(external_document)
    write_attribute("external_document", external_document)
    self.external_document_updated_at = Time.now
  end

  def document=(document)
    write_attribute("document", document)
    self.document_updated_at = Time.now
  end

  def merged_document
    doc = (external_document || {}).merge(document || {}).merge((occurrences.empty? ? {} : {'occurrences' => occurrences}))
    doc.empty? ? nil : doc
  end

  def uid
    "#{klass}:#{canonical_path}$#{id}"
  end

  def uid=(value)
    self.klass, self.canonical_path, _oid = Pebbles::Uid.parse(value)
    raise ArgumentError, "Do not assign oid. It is managed by the model. (omit '...$#{_oid}' from uid)" if _oid != '' && _oid != self.id
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
      $memcached.get_multi(*cache_keys.map {|key| CacheKey.wrap(key) }).map do |key, value|
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

  # TODO: When we have multiple versions of the api, we will need to
  # add validations to the Interceptor::Validator objects so that they have
  # a version, depending on the version of the api that is being used.
  # This is because the templates that are used in the interception/callback
  # are version-specific.
  def intercept_and_save!(session)
    intercept(session)
    self.save!
  end

  def intercept(session = nil)
    action = new_record? ? 'create' : 'update'
    Interceptor.process(self, {:session => session, :action => action})
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

  def remove_occurrences!(event, at = nil)
    if at.nil?
      OccurrenceEntry.where(:post_id => id, :label => event).destroy_all
    else
      OccurrenceEntry.where(:post_id => id, :label => event, :at => Array(at)).destroy_all
    end
  end

  def replace_occurrences!(event, at = [])
    remove_occurrences!(event)
    add_occurrences!(event, at)
  end

  private

  def invalidate_cache
    $memcached.delete(cache_key)
  end

  # TODO: Replace with something general. This is an ugly hack to make dittforslag.no scripthacking-safe.
  def sanitize
    return unless self.document.is_a?(Hash)
    ['text', 'author_name', 'email'].each do |field|
      self.document[field] = Sanitize.clean(self.document[field]) if self.document.has_key?(field)
    end
    self.document['text'] = self.document['text'][0..139] unless self.document['text'].nil?
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
    self.conflicted = (external_document_updated_at > document_updated_at and overridden_fields.any?)
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
    if self.deleted_changed?
      if self.deleted && self.external_id != nil
        self.document['external_id'] = self.external_id
        self.external_id = nil
      end
    end
  end

end
