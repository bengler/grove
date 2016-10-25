require 'spec_helper'

describe RiverNotifications do

  before(:each) do
    ActiveRecord::Base.add_observer RiverNotifications.instance
  end

  after(:each) do
    ActiveRecord::Base.observers = []
  end

  describe "create" do

    it "publishes the post with no changed_attributes entry" do
      expect_any_instance_of(RiverNotifications).to receive(:publish!) do |instance, arg|
        expect(arg[:event]).to eq :create
        expect(arg[:uid]).not_to be nil
        expect(arg[:attributes]).not_to be nil
        expect(arg[:attributes]['version']).to eq 1
        expect(arg[:changed_attributes]).to be nil
      end
      Post.create!(:canonical_path => 'this.that')
    end

  end

  describe "update" do

    it "publishes the post together with changed_attributes" do
      ActiveRecord::Base.observers.disable :all
      p = Post.create!(:canonical_path => 'this.that', :published => false, :document => {:text => 'blipp'})
      p.published = true
      p.document = {:text => 'jumped over the lazy dog'}
      ActiveRecord::Base.observers.enable :all
      expect_any_instance_of(RiverNotifications).to receive(:publish!) do |instance, arg|
        expect(arg[:event]).to eq :update
        expect(arg[:uid]).not_to be nil
        expect(arg[:attributes]).not_to be nil
        expect(arg[:attributes]['version']).to eq 2
        expect(arg[:changed_attributes][:published]).to eq [false, true]
        expect(arg[:changed_attributes][:document]).to eq [
          {'text' => "blipp"},
          {'text' => "jumped over the lazy dog"}
        ]
      end
      p.save!
    end

    it "publishes the post together with changed_attributes even if a serialized field has been updated" do
      ActiveRecord::Base.observers.disable :all
      p = Post.create!(:canonical_path => 'this.that', :published => false, :document => {:text => 'blipp'})
      p.document = p.document.merge(:text => 'jumped over the lazy dog')
      ActiveRecord::Base.observers.enable :all
      expect_any_instance_of(RiverNotifications).to receive(:publish!) do |instance, arg|
        expect(arg[:event]).to eq :update
        expect(arg[:uid]).not_to be nil
        expect(arg[:attributes]).not_to be nil
        expect(arg[:changed_attributes][:document]).to eq [
          {'text' => "blipp"},
          {'text' => "jumped over the lazy dog"}
        ]
      end
      p.save!
    end

  end

  describe "delete" do

    it "creates a delete event with the soft delete flag set" do
      ActiveRecord::Base.observers.disable :all
      p = Post.create!(:canonical_path => 'this.that', :document => {:text => 'blipp'})
      ActiveRecord::Base.observers.enable :all
      expect_any_instance_of(RiverNotifications).to receive(:publish!) do |instance, arg|
        expect(arg[:event]).to eq :delete
        expect(arg[:soft_deleted]).to be true
      end
      p.deleted = true
      p.save!
    end

  end

end
