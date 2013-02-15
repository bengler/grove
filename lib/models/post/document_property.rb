# Lets you access the Post#has_and_belongs_to_many :locations relation
# as if it was a set of strings. This supports persisting and retrieving
# a Post from json without hitting the database as would happen when
# reading through memcached.

class Post < ActiveRecord::Base

  after_save :sync_document_property

  def document
    @attributes['document'] ||= Field.for_post(self)
  end

  def document=(value)
    @attributes['document'] = value || {}
  end

  # Include the document property with the json hash
  alias_method :as_json_without_document, :as_json
  def as_json(*args)
    hash = self.as_json_without_document(*args)
    hash['post']['document'] = self.document
    hash
  end

  private

  # This ensures that any state is reset when the instance is reloaded
  alias_method :clear_aggregation_cache_without_document, :clear_aggregation_cache
  def clear_aggregation_cache
    @attributes['document'] = nil
    clear_aggregation_cache_without_document
  end

  def sync_document_property
    Field.update_all(self, @attributes['document']) if @attributes['document']
  end

end
