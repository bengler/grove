require 'spec_helper'

describe Post do
  it "can generate a path" do
    p = Post.new(:realm => "area51", :box => "vaktmesterkontoret", :collection => "forum1", :oid => "name")
    p.path.should eq "area51.vaktmesterkontoret.forum1"
  end

  it "can genereate an uid" do
    p = Post.new(:realm => "area51", :box => "vaktmesterkontoret", :collection => "forum1", :oid => "name")
    p.uid.should eq "post:area51.vaktmesterkontoret.forum1$name"
  end

  it "can retrieve one by uid" do
    Post.create!(:realm => "area51", :box => "vaktmesterkontoret", :collection => "forum1", :oid => "1", :document => "1")
    Post.create!(:realm => "area51", :box => "vaktmesterkontoret", :collection => "forum1", :oid => "2", :document => "2")
    Post.create!(:realm => "area51", :box => "vaktmesterkontoret", :collection => "forum2", :oid => "1", :document => "3")
    Post.find_by_uid("post:area51.vaktmesterkontoret.forum1$1").document.should eq '1'
    Post.find_by_uid("post:area51.vaktmesterkontoret.forum1$2").document.should eq '2'
    Post.find_by_uid("post:area51.vaktmesterkontoret.forum2$1").document.should eq '3'
    Post.find_by_uid("post:area51.vaktmesterkontoret.forum2$2").should be_nil
  end

  it "can assign realm, box, collection and oid by assigning uid" do
    p = Post.new(:uid => "post:area51.vaktmesterkontoret.forum1$name")
    p.realm.should eq "area51"
    p.box.should eq "vaktmesterkontoret"
    p.collection.should eq "forum1"
    p.oid.should eq "name"
  end
end