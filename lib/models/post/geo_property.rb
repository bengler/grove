# Lets you access the Post#has_and_belongs_to_many :locations relation
# as if it was a set of strings. This supports persisting and retrieving
# a Post from json without hitting the database as would happen when
# reading through memcached.

class Post < ActiveRecord::Base

  # A proxy class to present the locations relation as a set of strings
  class GeoAccessor
    def initialize(object, initial_value = nil)
      @object = object
      if initial_value
        self.lon = initial_value[:lon]
        self.lant = initial_value[:lat]
      end
    end

    def inspect
      "#<Post::GeoAccessor @lon=#{self.lon.inspect} @lat=#{self.lat.inspect}>"
    end

    # Syncs this list of paths with the location relation
    def lon
      @object.lon
    end

    def lat
      @object.lat
    end

    def lon=(value)
      @object.lon = value
    end

    def lat=(value)
      @object.lat = value
    end
  end

  def geo
    @geo_accessor ||= GeoAccessor.new(self)
  end

  def geo=(value)
    if value
      self.geo.lon = value[:lon]
      self.geo.lat = value[:lat]
      self.geo
    else
      @object.lon = nil
      @object.lat = nil
    end
  end

  # Include the paths property with the json hash
  alias_method :as_json_without_geo, :as_json
  def as_json(*args)
    hash = self.as_json_without_geo(*args)
    if self.lon || self.lat
      hash['post']['geo'] = { :lon => self.lon, :lat => self.lat}
    else
      hash['post']['geo'] = {}
    end
    hash['post'].delete('lon')
    hash['post'].delete('lat')
    hash
  end
end
