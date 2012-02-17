require 'delegate'

class Interceptor < SimpleDelegator
  class << self
    def process(post, options = {})
      find_posts_for(post, options).each do |post|
        Interceptor.new(post).with(options).process
      end
    end

    def find_posts_for(post, options = {})
      Post.filtered_by filters(post, options)
    end

    def filters(post, options)
      tags = []
      tags << options[:action] if options[:action]
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

  attr_accessor :action, :session, :identity_id
  def with(options = {})
    self.action = options[:action]
    self.session = options[:session]
    self.identity_id = options[:identity].id if options[:identity]
    self
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
