# Lets you access the Post#has_and_belongs_to_many :locations relation
# as if it was a set of strings. This supports persisting and retrieving
# a Post from json without hitting the database as would happen when
# reading through memcached.

class Post < ActiveRecord::Base

  after_save :sync_paths_property

  # A proxy class to present the locations relation as a set of strings
  class LocationsAccessor < Set
    def initialize(object, initial_value = nil)
      @object = object      
      super(initial_value || 
        @object.attributes['paths'] || 
        @object.locations.map{ |location| location.path.to_s })
    end

    # Syncs this list of paths with the location relation
    def save!
      @object.locations = self.map{ |path| Location.declare!(path) }
    end
  end

  def paths
    @locations_accessor ||= LocationsAccessor.new(self)
  end

  def paths=(value)
    @locations_accessor = LocationsAccessor.new(self, value)
  end

  # Include the paths property with the json hash
  alias_method :as_json_without_paths, :as_json
  def as_json(*args)
    hash = self.as_json_without_paths(*args)
    hash['post']['paths'] = self.paths
    hash
  end

  private

  # This ensures that any state is reset when the instance is reloaded
  alias_method :clear_aggregation_cache_without_paths, :clear_aggregation_cache
  def clear_aggregation_cache
    @locations_accessor = nil
    @attributes.delete('paths')
    clear_aggregation_cache_without_paths
  end

  def paths_need_sync?
    @attributes['paths'] || @locations_accessor
  end

  def sync_paths_property
    self.paths.save! if paths_need_sync?
  end

end
