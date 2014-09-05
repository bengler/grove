class Location < ActiveRecord::Base
  include Pebbles::Path

  has_and_belongs_to_many :posts, :uniq => true

  after_create :extend_group_access

  # returns true if the identity can access the location through its group_memberships
  def accessible_by?(identity_id)
    group_ids = GroupMembership.where(identity_id: identity_id).map(&:group_id)
    !GroupLocation.where('location_id = ? AND group_id in (?)', self.id, group_ids).limit(1).empty?
  end


  private

  def extend_group_access
    GroupLocation.extend_from_ancestors(self)
  end
end
