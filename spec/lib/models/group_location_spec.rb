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
    GroupLocation.is_included?(1,'norway.oslo').should be_true
    GroupLocation.is_included?(1,'norway.oslo.sagene').should be_true
    GroupLocation.is_included?(1,'norway.bergen.nordnes').should be_false
  end

  it "handles access granting in an idempotent way" do
    sample_tree
    GroupLocation.allow_subtree(1, "norway.oslo")
    count = GroupLocation.count
    GroupLocation.allow_subtree(1, "norway.oslo")
    GroupLocation.count.should eq count
  end

  it "is able to extend group access for new locations" do
    sample_tree
    GroupLocation.allow_subtree(1, "norway.oslo")
    Location.declare!("norway.oslo.grefsen")
    GroupLocation.is_included?(1,'norway.oslo.grefsen').should be_true
  end

  it "is able to deny access recursively" do
    sample_tree
    GroupLocation.allow_subtree(1, "norway.oslo")
    GroupLocation.is_included?(1,'norway.oslo.sagene').should be_true
    GroupLocation.deny_subtree(1, "norway.oslo")
    GroupLocation.is_included?(1,'norway.oslo.sagene').should be_false
    GroupLocation.is_included?(1,'norway.oslo').should be_false
  end
end
