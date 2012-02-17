require 'delegate'

class Interceptor < SimpleDelegator
  class << self
    def process(post, options = {})
      find_applicable(post, options).each do |interceptor|
        interceptor.process
      end
    end

    def find_applicable(post, options)
      Post.filtered_by(filters post, options[:action]).map { |post| Interceptor.new(post) }
    end

    def filters(post, action)
      tags = []
      tags << action
      tags << klass_to_tag(post.klass)
      {:realm => post.realm, :tags => tags.compact}
    end

    def klass_to_tag(s)
      s[/^[^\.]*\.(.*)$/, 1]
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
