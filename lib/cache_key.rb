require_relative './schema_version'

module CacheKey

  def self.wrap(key)
    SchemaVersion.tag_key key
  end

  def self.unwrap(key)
    SchemaVersion.untag_key key
  end

  def self.from_uid(uid)
    wrap Pebbles::Uid.cache_key(uid)
  end

  def cache_key
    @cache_key ||= CacheKey.from_uid(uid)
  end

end
