class Interceptor
  class << self
    def process(post, options = {})
      Interceptor.new(post, options).process
    end
  end

  attr_accessor :post, :options, :action
  def initialize(post, options = {})
    self.post = post
    self.options = options
    self.action = options[:action]
  end

  def process
    find_applicable.each do |post|
      Validator.new(post).with(options).process
    end
  end

  def find_applicable
    Post.filtered_by realm_and_tags
  end

  def realm_and_tags
    filters = {:realm => post.realm}
    filters[:tags] = tags unless tags.empty?
    filters
  end

  def tags
    tags = []
    tags << action
    tags << klass
    tags.compact
  end

  def klass
    post.klass[/^[^\.]*\.(.*)$/, 1]
  end
end
