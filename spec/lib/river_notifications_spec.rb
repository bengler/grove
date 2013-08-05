require 'spec_helper'

describe RiverNotifications do

  before(:each) do
    ActiveRecord::Base.add_observer RiverNotifications.instance
  end

  after(:each) do
    ActiveRecord::Base.observers = []
  end

  describe "create" do

    it "publishes the post without no diff" do
      Pebblebed::River.any_instance.should_receive(:publish) do |arg|
        arg[:event].should eq :create
        arg[:uid].should_not be nil
        arg[:attributes].should_not be nil
        arg[:changed_attributes].should be nil
      end
      Post.create!(:canonical_path => 'this.that')
    end

  end

  describe "update" do

    it "publishes the post with a diff" do
      p = Post.create!(:canonical_path => 'this.that')
      p.published = true
      Pebblebed::River.any_instance.should_receive(:publish) do |arg|
        arg[:event].should eq :update
        arg[:uid].should_not be nil
        arg[:attributes].should_not be nil
        arg[:changed_attributes][:published].should eq [nil, true]
      end
      p.save!
    end

  end

end
