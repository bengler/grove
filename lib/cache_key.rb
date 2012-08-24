require_relative './schema_version'

module CacheKey

  def self.from_uid(uid)
    _klass, _path, _oid = Pebblebed::Uid.parse(uid)
    SchemaVersion.tag_key "#{_klass}:*$#{_oid}"
  end

  def cache_key
    @cache_key ||= CacheKey.from_uid(uid)
  end

end
