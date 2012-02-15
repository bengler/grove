class Post < ActiveRecord::Base
  has_and_belongs_to_many :locations, :uniq => true

  validates_presence_of :realm

  validate :canonical_path_must_be_valid
  validates_format_of :klass, :with => /^post(\.|$)/

  before_save :sanitize
  before_validation :assign_realm, :set_default_klass
  before_save :attach_canonical_path
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
    scope = order('created_at DESC')
    scope = scope.where(:klass => filters['klass'].split(',').map(&:strip)) if filters['klass']
    scope = scope.with_tags(filters['tags']) if filters['tags']
    scope = scope.where(:created_by => filters['created_by']) if filters['created_by']
    scope
  }

  def uid
    "post:#{canonical_path}$#{self.id}"
  end

  def uid=(value)
    self.klass, self.canonical_path, _oid = Pebblebed::Uid.raw_parse(value)
    raise ArgumentError, "Do not assign oid. It is managed by the model. (omit '...$#{_oid}' from uid)" if _oid != '' && _oid != self.id
  end

  def self.find_by_uid(uid)
    return nil unless Pebblebed::Uid.new(uid).oid
    self.by_uid(uid).first
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
      error.add :base, "{self.canonical_path.inspect} is an invalid path."
    end
  end

  def set_default_klass
    self.klass ||= "post"
  end

end
