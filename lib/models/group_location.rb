# Defines which groups that have access to restricted content at a certain location
# Each entry in the group_locations table grants access to one single location for one particular group.
# The access semantics of Pebbles is hierarchical, and this class helps maintain all the individual
# records according to the hierarchy of access modelled by checkpoint.
class GroupLocation < ActiveRecord::Base
  belongs_to :location

  # Given the gorup_id and path, makes sure every path in the subtree gets a group_location entry
  def self.allow_subtree(group_id, path)
    raise ArgumentError, "Must be a valid path without wildcards" unless Pebbles::Uid.valid_path?(path)
    Location.declare!(path) # Must make sure the root path exists in the database
    Location.by_path("#{path}.*").each do |location|
      allow_location(group_id, location)
    end
  end

  # Given the group_id and path, removes any group_location entries for the entire subtree
  def self.deny_subtree(group_id, path)
    raise ArgumentError, "Must be a valid path without wildcards" unless Pebbles::Uid.valid_path?(path)
    location_ids = Location.by_path("#{path}.*").map(&:id)
    GroupLocation.delete_all(["group_id = ? and location_id in (?)", group_id, location_ids])
  end

  # Extends the group_location settings from any node above in the tree. Used when creating new
  # locations to give access to the proper groups.
  def self.extend_from_ancestors(location)
    ancestor_ids = Location.by_path("^#{location.path}").map(&:id)
    # Find all group ids with access to the tree above the location of interest
    return if ancestor_ids.empty?
    group_ids = GroupLocation.connection.
      select_values("select distinct group_id from group_locations where location_id in (#{ancestor_ids.join(',')})")
    # Grant access to this location for all groups with access to the ancestors
    group_ids.each do |group_id|
      allow_location(group_id, location)
    end
  end

  # Check if the location at the provided path has access for the group indicated. Will return nil
  # meaning the answer is unknown if there is no location record for the path given. This info is not really
  # unknowable for hypothetical locations, but currently this method is just aid used in tests.
  def self.is_included?(group_id, path)
    location = Location.by_path(path).first
    return nil unless location # undefined
    !!(GroupLocation.where(:group_id => group_id, :location_id => location.id).first)
  end

  private

  # Makes sure there is a single group_location entry for the given group_id and location
  def self.allow_location(group_id, location)
    GroupLocation.where(:group_id => group_id, :location_id => location.id).first ||
      GroupLocation.create!(:group_id => group_id, :location_id => location.id)
  end
end
