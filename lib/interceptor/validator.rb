require 'delegate'
class Interceptor

  class Validator < SimpleDelegator
    def to_model
      __getobj__
    end

    alias_method :__class__, :class
    def class
      __getobj__.class
    end

    attr_accessor :action, :session
    def with(options = {})
      self.action = options[:action]
      self.session = options[:session]
      self
    end

    def url
      @url ||= document[:url]
    end

    def tagify(tags)
      tags ||= ''
      tags = tags.split(',') if tags.respond_to?(:split)
      tags.map(&:strip)
    end

    def validate(post)
      Callback.new(self, post).execute
    end

  end
end
