require 'spec_helper'

describe GroupLocation do 
  let :sample_tree do
    Location.declare!("norway.oslo.sagene")
    Location.declare!("norway.oslo.frogner")
    Location.declare!("norway.bergen.nordnes")
  end

  it "is able to assign group access recursively" do
    sample_tree
    GroupLocation.allow_subtree(1, "norway.oslo")
    expect(GroupLocation.is_included?(1,'norway.oslo')).to be_truthy
    expect(GroupLocation.is_included?(1,'norway.oslo.sagene')).to be_truthy
    expect(GroupLocation.is_included?(1,'norway.bergen.nordnes')).to be_falsey
  end

  it "handles access granting in an idempotent way" do
    sample_tree
    GroupLocation.allow_subtree(1, "norway.oslo")
    count = GroupLocation.count
    GroupLocation.allow_subtree(1, "norway.oslo")
    expect(GroupLocation.count).to eq count
  end

  it "is able to extend group access for new locations" do
    sample_tree
    GroupLocation.allow_subtree(1, "norway.oslo")
    Location.declare!("norway.oslo.grefsen")
    expect(GroupLocation.is_included?(1,'norway.oslo.grefsen')).to be_truthy
  end

  it "is able to deny access recursively" do
    sample_tree
    GroupLocation.allow_subtree(1, "norway.oslo")
    expect(GroupLocation.is_included?(1,'norway.oslo.sagene')).to be_truthy
    GroupLocation.deny_subtree(1, "norway.oslo")
    expect(GroupLocation.is_included?(1,'norway.oslo.sagene')).to be_falsey
    expect(GroupLocation.is_included?(1,'norway.oslo')).to be_falsey
  end
end
