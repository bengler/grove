class CacheKeychain

  attr_reader :data, :marks
  def initialize(uids)
    @data = {}
    @marks = []

    uids.each do |uid|
      @data[CacheKey.from_uid(uid)] = uid
    end
  end

  def keys
    @data.keys
  end

  def mark(keys)
    @marks += Array(keys)
  end

  def unmarked
    result = {}
    (keys - marks).each do |key|
      result[key] = data[key]
    end
    result
  end

  def marked
    result = {}
    marks.each do |key|
      result[key] = data[key]
    end
    result
  end

end
