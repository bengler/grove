class Post < ActiveRecord::Base
  scope :with_tags, lambda { |tags|
    tags = Post.parse_tag_string(tags) if tags.is_a?(String)
    tags.map!{ |tag| Post.normalize_tag(tag) }
    where("tags_vector @@ to_tsquery('simple', ?) ", tags.join(' & '))
  }

  def tags=(value)
    return self.tags_vector = nil if value.nil?
    value = Post.parse_tag_string(value) if value.is_a?(String)
    self.tags_vector = value.map{ |tag| "'#{Post.normalize_tag(tag)}'" }.join(' ')
  end

  def tags
    return [] unless self.tags_vector
    self.tags_vector.scan(/'(.+?)'/).flatten
  end

  def self.normalize_tag(tag)
    tag.downcase.gsub(/[^[:alnum:]]/, "")
  end

  def self.parse_tag_string(tags)
    tags.split(/\s*,\s*/)
  end

end