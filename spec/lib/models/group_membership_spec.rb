require 'spec_helper'

describe GroupMembership do
  it "can be declared" do
    GroupMembership.declare!(1,2)
    GroupMembership.count.should eq 1
    GroupMembership.first.group_id.should eq 1
    GroupMembership.first.identity_id.should eq 2
  end

  it "can be removed" do
    GroupMembership.declare!(1,2)
    GroupMembership.declare!(1,3)
    GroupMembership.count.should eq 2
    GroupMembership.remove!(1,3)
    GroupMembership.count.should eq 1
  end

  it "is idempotent" do
    GroupMembership.declare!(1,2)
    GroupMembership.declare!(1,2)
    GroupMembership.count.should eq 1
  end
end
