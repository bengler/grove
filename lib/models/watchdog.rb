require 'delegate'

class Watchdog < SimpleDelegator
  def to_model
    __getobj__
  end

  alias_method :__class__, :class
  def class
    __getobj__.class
  end

  def actions
    tags
  end

  def klasses
    @klass ||= tagify document[:klasses]
  end

  def paths
    @paths ||= tagify document[:paths]
  end

  def url
    @url ||= document[:url]
  end

  def tagify(tags)
    tags ||= ''
    tags = tags.split(',') if tags.respond_to?(:split)
    tags.map(&:strip)
  end
end
