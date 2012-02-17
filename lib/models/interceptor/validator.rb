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
end
