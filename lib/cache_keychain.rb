# Maps cache keys to uids in order to mediate
# storage and retrieval from cache for a collection
# of uids.
#
# This is necessary because many different uids
# point to the same object (due to alternate path
# semantics).
#
class CacheKeychain

  def initialize(uids)
    @key_to_uid_map = {}
    @marked_keys = []

    uids.each do |uid|
      @data[CacheKey.from_uid(uid)] = uid
    end
  end

  # Marking one or more cache key as seen.
  def mark(cache_keys)
    @marked_keys += Array(cache_keys)
  end

  # Returns a map of {cache_key => uid} for those
  # items which have not been marked as seen.
  def unmarked
    result = {}
    (keys - marked_keys).each do |key|
      result[key] = data[key]
    end
    result
  end

  def keys
    @key_to_uid_map.keys
  end


  private
  def marked_keys
    @marked_keys
  end


end
