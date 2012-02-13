# Lets you access the Post#has_many :occurrence_entries relation
# as if it was a hash of array of Time. This supports persisting and retrieving
# a Post from json without hitting the database as would happen when
# reading through memcached.

class Post < ActiveRecord::Base
  has_many :occurrence_entries

  after_save :sync_occurrences_property

  # A proxy class to present the occurrence_entries relation as a hash of timestamps
  class OccurrencesAccessor < Hash
    def initialize(object, initial_value = nil)
      super()
      @object = object
      initial_value ||= @object.attributes['occurrences']
      initial_value ? self.replace(initial_value) : self.reload
    end

    def reload
      result = Hash.new([])
      @object.occurrence_entries.each { |occurrence| result[occurrence.label] |= [occurrence.at] }
      self.replace(result)
    end

    # Syncs this hash of occurrences with the occurrence_entriess relation
    def save!
      parse_timestamps
      # Create a deep copy of self and convert all timestamps to rfc822 to avoid OS specific rounding aberrations
      to_sync = Hash[self.keys.map { |label| [label, self[label].map(&:rfc822)] }]
      # Check existing occurrence_entries
      @object.occurrence_entries.each do |occurrence|
        # Delete occurrences that are not in this hash
        occurrence.destroy unless to_sync.has_key?(occurrence.label) && to_sync[occurrence.label].include?(occurrence.at.rfc822)
        # Remove existing occurrences from the hash of occurrences to create
        to_sync[occurrence.label].delete(occurrence.at.rfc822) if to_sync.has_key?(occurrence.label)
      end
      # Create missing occurrences
      to_sync.each do |label, timestamps|
        timestamps.each do |rfc822_timestring|
          OccurrenceEntry.create!(:post => @object, :label => label, :at => Time.rfc822(rfc822_timestring))
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

  attr_accessor :occurrences

  def occurrences
    @occurrences_accessor ||= OccurrencesAccessor.new(self)
  end

  def occurrences=(value)
    @occurrences_accessor = OccurrencesAccessor.new(self, value)
  end

  # Include the paths property with the json hash
  alias_method :as_json_without_occurrences, :as_json
  def as_json(*args)
    hash = self.as_json_without_occurrences(*args)
    hash['post']['occurrences'] = self.occurrences
    hash
  end

  private

  # This ensures that any state is reset when the instance is reloaded
  alias_method :clear_aggregation_cache_without_occurrences, :clear_aggregation_cache
  def clear_aggregation_cache
    @occurrences_accessor = nil
    @attributes.delete('occurrences')
    clear_aggregation_cache_without_occurrences
  end

  def occurrences_need_sync?
    @attributes['occurrences'] || @occurrences_accessor
  end

  def sync_occurrences_property
    self.occurrences.save! if occurrences_need_sync?
  end

end