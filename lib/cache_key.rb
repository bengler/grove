module CacheKey

  def self.from_uid(uid)
    _klass, _path, _oid = Pebblebed::Uid.parse(uid)
    "#{_klass}:*$#{_oid}"
  end

  def cache_key
    @cache_key ||= CacheKey.from_uid(uid)
  end

end
