require 'spec_helper'

describe "API v1 posts" do
  include Rack::Test::Methods

  def app
    GroveV1
  end

  context "with a logged in user" do
    before :each do
      Pebbles::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {:id=>1337, :god? => false}))
    end

    it "can post a document" do
      post "/posts/post:a.b.c$d", {:document => "hello world"}
      Post.find_by_uid("post:a.b.c$d").document.should eq "hello world"
    end

    it "can update a document" do
      post "/posts/post:a.b.c$d", {:document => "hello world"}
      post "/posts/post:a.b.c$d", {:document => "hello universe"}
      Post.find_by_uid("post:a.b.c$d").document.should eq "hello universe"
    end

    it "can't update a document created by another user" do
      Post.create!(:uid => "post:a.b.c$d", :created_by => 1, :document => "Hello spaceboy")
      post "/posts/post:a.b.c$d", {:document => "hello nobody"}
      last_response.status.should eq 403
    end

    it "can retrieve a document" do
      Post.create!(:uid => "post:a.b.c$d", :created_by => 1, :document => "Hello spaceboy")
      get "/posts/post:a.b.c$d"
      result = JSON.parse(last_response.body)['post']
      result['uid'].should eq "post:a.b.c$d"
      result['created_by'].should eq 1
      result['document'].should eq "Hello spaceboy"
    end

    it "can retrieve a collection of documents" do
      10.times do |i|
        Post.create!(:uid => "post:a.b.c$doc#{i}", :document => i.to_s)
      end
      Post.create!(:uid => "post:a.b.d$doc1", :document => "a")
      get "/posts/post:*"
      result = JSON.parse(last_response.body)
      result['posts'].size.should eq 11
      result['posts'].first['post']['document'].should eq 'a'
      result['posts'].last['post']['document'].should eq '0'

      get "/posts/post:*", :limit => 2
      result = JSON.parse(last_response.body)
      result['posts'].size.should eq 2
      result['posts'].first['post']['document'].should eq 'a'
      result['posts'].last['post']['document'].should eq '9'
      result['pagination']['limit'].should eq 2

      get "/posts/post:a.b.*"
      result = JSON.parse(last_response.body)
      result['posts'].size.should eq 11

      get "/posts/post:a.b.d$*"
      result = JSON.parse(last_response.body)
      result['posts'].size.should eq 1

      get "/posts/post:*$doc1"
      result = JSON.parse(last_response.body)
      result['posts'].size.should eq 2

    end

  end

  context "with a logged in god" do
    before :each do
      Pebbles::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {:id=>1337, :god? => true}))
    end

    it "can update a document created by another user without modifying created_by field" do
      Post.create!(:uid => "post:a.b.c$d", :created_by => 1, :document => "Hello spaceboy")
      post "/posts/post:a.b.c$d", {:document => "hello nobody"}
      last_response.status.should eq 200
      result = JSON.parse(last_response.body)['post']
      result['created_by'].should eq 1
    end

  end
end