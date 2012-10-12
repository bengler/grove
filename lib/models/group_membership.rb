# This simple model keeps track of who is a member of what group
class GroupMembership < ActiveRecord::Base
  def self.declare!(group_id, identity_id)
    GroupMembership.where(:group_id => group_id, :identity_id => identity_id).first ||
      GroupMembership.create!(:group_id => group_id, :identity_id => identity_id)
  end

  def self.remove!(group_id, identity_id)
    GroupMembership.delete_all("group_id = #{group_id.to_i} and identity_id = #{identity_id.to_i}")
  end
end