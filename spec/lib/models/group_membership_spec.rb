require 'spec_helper'

describe GroupMembership do
  it "can be declared" do
    GroupMembership.declare!(1,2)
    expect(GroupMembership.count).to eq 1
    expect(GroupMembership.first.group_id).to eq 1
    expect(GroupMembership.first.identity_id).to eq 2
  end

  it "can be removed" do
    GroupMembership.declare!(1,2)
    GroupMembership.declare!(1,3)
    expect(GroupMembership.count).to eq 2
    GroupMembership.remove!(1,3)
    expect(GroupMembership.count).to eq 1
  end

  it "is idempotent" do
    GroupMembership.declare!(1,2)
    GroupMembership.declare!(1,2)
    expect(GroupMembership.count).to eq 1
  end
end
