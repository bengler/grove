class Post < ActiveRecord::Base
  class CanonicalPathConflict < StandardError; end

  has_and_belongs_to_many :locations, :uniq => true, 
    :after_add => :increment_unread_counts,
    :after_remove => :decrement_unread_counts

  validates_presence_of :realm

  validate :canonical_path_must_be_valid
  validates_format_of :klass, :with => /^post(\.|$)/

  before_save :sanitize
  before_validation :assign_realm, :set_default_klass
  before_save :attach_canonical_path
  before_save :update_readmarks_according_to_deleted_status
  after_update :invalidate_cache
  before_destroy :invalidate_cache

  default_scope where("not deleted")

  include TsVectorTags
  serialize :document

  scope :by_path, lambda { |path|
    select("distinct posts.*").joins(:locations).where(:locations => Location.parse_path(path)) unless path == '*'
  }

  scope :by_uid, lambda { |uid|
    _klass, _path, _oid = Pebblebed::Uid.raw_parse(uid)
    scope = by_path(_path)
    scope = scope.where("klass = ?", _klass) unless _klass == '*'
    scope = scope.where("posts.id = ?", _oid) unless _oid == '' || _oid == '*'
    scope
  }

  scope :filtered_by, lambda { |filters|
    scope = relation
    scope = scope.where(:realm => filters['realm']) if filters['realm']
    scope = scope.where(:klass => filters['klass'].split(',').map(&:strip)) if filters['klass']
    scope = scope.where(:external_id => filters['external_id'].split(',').map(&:strip)) if filters['external_id']
    scope = scope.with_tags(filters['tags']) if filters['tags']
    scope = scope.where(:created_by => filters['created_by']) if filters['created_by']
    scope
  }

  scope :with_restrictions, lambda { |identity|
    scope = relation
    if identity == nil || ! identity.respond_to?(:id)
      scope = scope.where(:restricted => false)
    elsif !(identity.respond_to?(:god) && identity.god)
      scope = scope.where('restricted = false or created_by = ?', identity.id)
    end
    scope
  }

  def visible_to?(identity)
    return true unless self.restricted
    return true if identity && identity.respond_to?(:god) && identity.god
    return (identity && identity.respond_to?(:id) && identity.id == self.created_by)
  end

  def may_be_managed_by?(identity)
    new_record? || identity.god || created_by == identity.id
  end

  def uid
    "#{klass}:#{canonical_path}$#{id}"
  end

  def uid=(value)
    self.klass, self.canonical_path, _oid = Pebblebed::Uid.raw_parse(value)
    raise ArgumentError, "Do not assign oid. It is managed by the model. (omit '...$#{_oid}' from uid)" if _oid != '' && _oid != self.id
  end

  def self.find_by_uid(uid)
    return nil unless Pebblebed::Uid.new(uid).oid
    self.by_uid(uid).first
  end

  def self.find_by_external_id_and_uid(external_id, provided_uid)
    return nil if external_id.nil?

    uid = Pebblebed::Uid.new(provided_uid)
    post = self.where(:realm => uid.realm, :external_id => external_id).first
    if post && post.canonical_path != uid.path
      fail CanonicalPathConflict.new(post.uid)
    end
    post
  end

  def self.cached_find_all_by_uid(uids)
    raise ArgumentError, "No wildcards allowed" if uids.join =~ /[\*\|]/
    result =  Hash[
      $memcached.get_multi(*SchemaVersion.tag_keys(uids)).map do |key, value|
        post = Post.instantiate(Yajl::Parser.parse(value))
        post.readonly!
        [SchemaVersion.untag_key(key), post]
      end
    ]
    uncached = uids-result.keys
    uncached.each do |uid|
      post = Post.find_by_uid(uid)
      $memcached.set(SchemaVersion.tag_key(uid), post.attributes.to_json) if post
      result[uid] = post
    end
    uids.map{|uid| result[uid]}
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
    Location.declare!(path).posts << self
  end

  def remove_path!(path)
    if path == canonical_path
      raise ArgumentError.new(:cannot_delete_canonical_path)
    end

    location = self.locations.by_path(path).first
    location.posts -= [self]
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
    $memcached.delete(SchemaVersion.tag_key(self.uid))
  end

  # TODO: Replace with something general. This is an ugly hack to make dittforslag.no scripthacking-safe.
  def sanitize
    return unless self.document.is_a?(Hash)
    ['text', 'author_name', 'email'].each do |field|
      self.document[field] = Sanitize.clean(self.document[field])
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
    unless Pebblebed::Uid.valid_path?(self.canonical_path)
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
end
