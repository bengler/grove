# Lets you access the Post#has_many :occurence_entries relation
# as if it was a hash of array of Time. This supports persisting and retrieving
# a Post from json without hitting the database as would happen when
# reading through memcached.

class Post < ActiveRecord::Base
  has_many :occurence_entries

  after_save :sync_occurences_property

  # A proxy class to present the occurence_entries relation as a hash of timestamps
  class OccurencesAccessor < Hash
    def initialize(object, initial_value = nil)
      super()
      @object = object
      initial_value ||= @object.attributes['occurences']
      initial_value ? self.replace(initial_value) : self.reload
    end

    def reload
      result = Hash.new([])
      @object.occurence_entries.each { |occurence| result[occurence.label] |= [occurence.at] }
      self.replace(result)
    end

    # Syncs this hash of occurences with the occurence_entriess relation
    def save!
      parse_timestamps
      # Create a deep copy of self and convert all timestamps to rfc822 to avoid OS specific rounding aberrations
      to_sync = Hash[self.keys.map { |label| [label, self[label].map(&:rfc822)] }]
      # Check existing occurence_entries
      @object.occurence_entries.each do |occurence|
        # Delete occurences that are not in this hash
        occurence.destroy unless to_sync.has_key?(occurence.label) && to_sync[occurence.label].include?(occurence.at.rfc822)
        # Remove existing occurences from the hash of occurences to create
        to_sync[occurence.label].delete(occurence.at.rfc822) if to_sync.has_key?(occurence.label)
      end
      # Create missing occurences
      to_sync.each do |label, timestamps|
        timestamps.each do |rfc822_timestring|
          OccurenceEntry.create!(:post => @object, :label => label, :at => Time.rfc822(rfc822_timestring))
        end
      end
    end

    # If the values of this hash contains strings that can be parsed Time.parse, they are parsed and replaced
    # with an instance of Time.
    def parse_timestamps
      self.keys.each do |key|
        self[key].map! do |timestamp| 
          timestamp.is_a?(Time) ? timestamp : Time.parse(timestamp)
        end
      end
    end
  end

  attr_accessor :occurences

  def occurences
    @occurences_accessor ||= OccurencesAccessor.new(self)
  end

  def occurences=(value)
    @occurences_accessor = OccurencesAccessor.new(self, value)
  end

  # Include the paths property with the json hash
  alias_method :as_json_without_occurences, :as_json
  def as_json(*args)
    hash = self.as_json_without_occurences(*args)
    hash['post']['occurences'] = self.occurences
    hash
  end

  private

  # This ensures that any state is reset when the instance is reloaded
  alias_method :clear_aggregation_cache_without_occurences, :clear_aggregation_cache
  def clear_aggregation_cache
    @occurences_accessor = nil
    @attributes.delete('occurences')
    clear_aggregation_cache_without_occurences
  end

  def occurences_need_sync?
    @attributes['occurences'] || @occurences_accessor
  end

  def sync_occurences_property
    self.occurences.save! if occurences_need_sync?
  end

end