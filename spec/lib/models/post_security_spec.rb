# These tests cover group-related security. For plain restrited documents, see post_spec.rb

require 'spec_helper'

describe "Post security" do
  let :restricted_post do
    post = Post.new
    post.canonical_path = 'norway.oslo.sagene'
    post.restricted = true
    post.save!
    post
  end

  let :invisible_restricted_post do
    post = Post.new
    post.canonical_path = 'norway.bergen.sagene'
    post.restricted = true
    post.save!
    post
  end

  let :member do
    GroupMembership.create!(:group_id => 1, :identity_id => 1)
    DeepStruct.wrap(:id => 1, :god => false)
  end

  let :non_member do
    DeepStruct.wrap(:id => 2, :god => false)
  end

  it "limits visibility" do
    restricted_post
    invisible_restricted_post
    Post.with_restrictions(member).count.should eq 0
    GroupLocation.allow_subtree(1, "norway.oslo")
    Post.with_restrictions(member).count.should eq 1
    Post.with_restrictions(non_member).count.should eq 0
    Post.with_restrictions(nil).count.should eq 0
  end

  it "extends visibility for late arriving documents" do
    GroupLocation.allow_subtree(1, "norway.oslo")
    restricted_post
    Post.with_restrictions(member).count.should eq 1
  end

end
