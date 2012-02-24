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
    find_applicable.each do |validator|
      self.post = Validator.new(validator).with(options).validate(post)
    end
    post
  end

  def find_applicable
    Post.filtered_by filter_options
  end

  def filter_options
    filters = {'realm' => post.realm}
    filters['tags'] = tags unless tags.empty?
    filters
  end

  def tags
    tags = []
    tags << action
    tags << klass
    tags.compact.map(&:to_s)
  end

  def klass
    post.klass[/^[^\.]*\.(.*)$/, 1]
  end
end
