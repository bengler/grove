require 'delegate'

class Interceptor < SimpleDelegator
  class << self
    def process(post, options = {})
      Post.filtered_by(:realm => post.realm, :tags => options[:action])
    end
  end

  def to_model
    __getobj__
  end

  alias_method :__class__, :class
  def class
    __getobj__.class
  end

  def klasses_and_actions
    tags
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
