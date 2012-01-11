class Post < ActiveRecord::Base

  validates_presence_of :realm
  validates_presence_of :box
  validates_presence_of :collection

  after_update :invalidate_cache
  before_destroy :invalidate_cache
  serialize :document

  default_scope where("not deleted")

  scope :by_uid, lambda { |uid|
    _realm, _box, _collection, _oid = Post.parse_uid(uid)
    where("id = ?", _oid)
  }

  scope :by_wildcard_uid, lambda { |uid| 
    _realm, _box, _collection, _oid = Post.parse_uid_without_validation(uid).map { |value| value == '*' ? nil : value }
    posts = self.scoped
    posts = posts.where(:realm => _realm) if _realm
    posts = posts.where(:box => _box) if _box
    posts = posts.where(:collection => _collection) if _collection
    posts = posts.where(:id => _oid) if _oid
    posts
  }

  def path
    "#{realm}.#{box}.#{collection}"
  end

  def uid
    "post:#{path}$#{self.id}"
  end

  def uid=(value)
    self.realm, self.box, self.collection, _oid = Post.parse_uid(value)
    raise ArgumentError, "Do not assign oid. It is managed by the model. (omit '...$#{_oid}' from uid)" if _oid && _oid != self.id
  end

  def self.find_by_uid(uid)
    self.by_uid(uid).first    
  end

  def self.parse_uid(uid)
    _klass, _path, _oid = Pebblebed::Uid.parse(uid)
    _realm, _box, _collection = _path.nil? ? [] : _path.split('.')
    [_realm, _box, _collection, _oid]    
  end

  def self.parse_uid_without_validation(uid)
    _klass, _path, _oid = Pebblebed::Uid.raw_parse(uid)
    _oid = nil if _oid == ''
    _realm, _box, _collection = _path.nil? ? [] : _path.split('.')
    [_realm, _box, _collection, _oid]    
  end

  def self.cached_find_all_by_uid(uids)
    result =  Hash[
      $memcached.get_multi(*uids).map do |key, value| 
        post = Post.instantiate(Yajl::Parser.parse(value))
        post.readonly!
        [key, post]
      end
    ]
    uncached = uids-result.keys
    uncached.each do |uid|
      post = Post.find_by_uid(uid)
      $memcached.set(uid, post.attributes.to_json) if post
      result[uid] = post
    end
    uids.map{|uid| result[uid]}
  end

  def invalidate_cache
    $memcached.delete(self.uid)
  end

  include TsVectorTags
end
