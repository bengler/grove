class AppValidation

  class << self
    def from_post(post)
      attributes = convert(post.attributes)
      AppValidation.new(attributes.merge(:post => post))
    end

    def convert(post_attributes)
      post = DeepStruct.wrap(post_attributes)
      {
        :actions => post.tags,
        :paths => post.document.paths,
        :klasses => post.document.klasses,
        :realm => post.realm,
        :url => post.document.url,
        :uid => post.uid,
        :created_by => post.created_by
      }
    end
  end

  attr_accessor :realm, :url, :actions, :paths, :klasses, :created_by, :post
  attr_writer :uid
  def initialize(options)
    self.actions = tagify options.delete(:actions)
    self.paths = tagify options.delete(:paths)
    self.klasses = tagify options.delete(:klasses)
    self.realm = options[:realm]
    self.url = options[:url]
    self.uid = options[:uid]
    self.post = options[:post]
    self.created_by = options[:created_by]
  end

  def uid
    @uid ||= "post.app_validation:#{realm}"
  end

  def as_json
    {
      :created_by => created_by,
      :realm => realm,
      :uid => uid,
      :tags => actions.join(','),
      :document => {
        :paths => paths.join(','),
        :klasses => klasses.join(','),
        :url => url
      }
    }
  end

  def tagify(tags)
    tags ||= ''
    tags = tags.split(',') if tags.respond_to?(:split)
    tags.map(&:strip)
  end
end
