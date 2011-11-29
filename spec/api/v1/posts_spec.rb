require 'spec_helper'

describe "API v1 posts" do
  include Rack::Test::Methods

  def app
    GroveV1
  end

  context "with a logged in user" do
    before :each do
      Pebbles::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {:id=>1337, :god => false}))
    end

    it "can post a document" do
      post "/posts/post:a.b.c", {:document => {content: "hello world"}}
      uid = JSON.parse(last_response.body)['post']['uid']
      Post.find_by_uid(uid).document['content'].should eq "hello world"
    end

    it "can post a tagged document" do
      post "/posts/post:a.b.c", {:document => "taggable", :tags => "paris, texas"}
      Post.first.tags.should eq ['paris', 'texas']
    end

    it "can retrieve a tagged document" do
      Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => '1')
      Post.create!(:uid => "post:a.b.c", :tags => ["paris", "texas"], :document => '2')
      Post.create!(:uid => "post:a.b.c", :tags => ["lyon", "france"], :document => '3')
      get "/posts/post:*", :tags => "texas"
      result = JSON.parse(last_response.body)['posts']
      result.size.should eq 1
      result.first['post']['document'].should eq "2"

      get "/posts/post:*", :tags => "paris"
      result = JSON.parse(last_response.body)['posts']
      result.size.should eq 2

      get "/posts/post:*", :tags => "texas, paris"
      result = JSON.parse(last_response.body)['posts']
      result.size.should eq 1
    end

    it "can update a document" do
      post "/posts/post:a.b.c", {:document => {:title => 'Hello spaceboy'}}
      uid = JSON.parse(last_response.body)['post']['uid']
      post "/posts/#{uid}", {:document =>  {:title => 'Hello universe'}}
      Post.find_by_uid(uid).document['title'].should eq "Hello universe"
    end

    it "can't update a document created by another user" do
      p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'})
      post "/posts/#{p.uid}", {:document => '{"title":"Hello nobody"}'}
      last_response.status.should eq 403
    end

    it "can retrieve a document" do
      p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'})
      get "/posts/#{p.uid}"
      result = JSON.parse(last_response.body)['post']
      result['uid'].should eq "post:a.b.c$#{p.id}"
      result['created_by'].should eq 1
      result['document']['title'].should eq "Hello spaceboy"
    end

    it "can retrieve a list of documents" do
      10.times do |i|
        Post.create!(:uid => "post:a.b.c", :document => i.to_s)
      end
      posts = Post.limit(3).order('created_at desc').all
      get "/posts/#{[posts.map(&:uid), "post:does.not.exist$99999999"].flatten.join(',')}"
      result = JSON.parse(last_response.body)['posts']
      result.size.should eq 4
      result.first['post']['document'].should eq posts.first.document
      result.last['post']['document'].should eq nil
    end

    it "can retrieve a collection of documents" do
      10.times do |i|
        Post.create!(:uid => "post:a.b.c", :document => i.to_s)
      end
      Post.create!(:uid => "post:a.b.d", :document => "a")
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

      get "/posts/post:a.b.*"
      result = JSON.parse(last_response.body)
      result['posts'].size.should eq 11

      get "/posts/post:a.b.d$*"
      result = JSON.parse(last_response.body)
      result['posts'].size.should eq 1

      post = Post.first
      get "/posts/post:*$#{post.id}"
      result = JSON.parse(last_response.body)
      result['posts'].size.should eq 1
    end

    it "can page through documents" do
      20.times do |i|
        Post.create!(:uid => "post:a.b.c", :document => i.to_s)        
      end

      get "/posts/post:*", :limit => 10, :offset => 2
      result = JSON.parse(last_response.body)
      result['posts'].size.should eq 10
      result['posts'].first['post']['document'].should eq "17"
      result['posts'].last['post']['document'].should eq "8"
      result['pagination']['last_page'].should be_false
      result['pagination']['limit'].should eq 10
      result['pagination']['offset'].should eq 2

      get "/posts/post:*", :limit => 10, :offset => 15
      result = JSON.parse(last_response.body)
      result['posts'].size.should eq 5
      result['posts'].first['post']['document'].should eq "4"
      result['posts'].last['post']['document'].should eq "0"
      result['pagination']['last_page'].should be_true
      result['pagination']['limit'].should eq 10
      result['pagination']['offset'].should eq 15
    end

  end

  context "with a logged in god" do
    before :each do
      Pebbles::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {:id=>1337, :god => true}))
    end

    it "can update a document created by another user without modifying created_by field" do
      p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => "Hello spaceboy")
      post "/posts/#{p.uid}", {:document => "hello nobody"}
      last_response.status.should eq 200
      result = JSON.parse(last_response.body)['post']
      result['created_by'].should eq 1
    end
  end

  context "with no current user" do
    before :each do
      Pebbles::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {:id=>nil, :god => nil}))
    end

    it "can't create posts" do
      post "/posts/post:a.b.c", {:document => "hello nobody"}
      last_response.status.should eq 403
    end

  end

end