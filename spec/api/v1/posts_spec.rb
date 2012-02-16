require 'spec_helper'

describe "API v1 posts" do
  include Rack::Test::Methods

  def app
    GroveV1
  end

  context "with a logged in user" do
    before :each do
      Pebblebed::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {:id=>1337, :god => false}))
    end

    describe "POST /posts/:uid" do

      it "creates a document" do
        post "/posts/post:a.b.c", :post => {:document => {content: "hello world"}}
        uid = JSON.parse(last_response.body)['post']['uid']
        Post.find_by_uid(uid).document['content'].should eq "hello world"
      end

      it "creates a tagged document" do
        post "/posts/post:a.b.c", :post => {:document => "taggable", :tags => "paris, texas"}
        Post.first.tags.should eq ['paris', 'texas']
      end

      it "updates a document" do
        post "/posts/post:a.b.c", :post => {:document => {:title => 'Hello spaceboy'}}
        uid = JSON.parse(last_response.body)['post']['uid']
        post "/posts/#{uid}", :post => {:document =>  {:title => 'Hello universe'}}
        Post.find_by_uid(uid).document['title'].should eq "Hello universe"
      end

      it "can't update a document created by another user" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'})
        post "/posts/#{p.uid}", :post => {:document => '{"title":"Hello nobody"}'}
        last_response.status.should eq 403
      end

      it "can post with external_id and avoid duplicates" do
        post "/posts/post:a.b.c", :post => {:document => {content: "hello world"}, :external_id => "unique"}
        last_response.status.should eq 201
        # Posting again with same path and same external id will update the post
        post "/posts/post:a.b.c", :post => {:document => {content: "hello again"}, :external_id => "unique"}
        last_response.status.should eq 200
        Post.count.should eq 1
        Post.first.document['content'].should eq "hello again"
        post "/posts/post:a.other.path", :post => {:document => {content: "hello mars"}, :external_id => "unique"}
        last_response.status.should eq 409 # conflict because of other path
        Post.first.document['content'].should eq "hello again"
        # Post to same path with different external_id creates a new document
        post "/posts/post:a.b.c", :post => {:document => {content: "hello again"}, :external_id => "other-unique"}
        Post.count.should eq 2
        last_response.status.should eq 201
      end

      it "can post to multiple paths" do
        post "/posts/post:a.b.c", :post => {:document => {}, :paths => ['a.b.secondary']}
        Post.by_path('a.b.c').count.should eq 1
        Post.by_path('a.b.secondary').count.should eq 1
        get "/posts/#{Post.first.uid}"
        JSON.parse(last_response.body)['post']['paths'].sort.should eq ['a.b.secondary', 'a.b.c'].sort
      end

      it "can contain occurrences in time" do
        timestamp = Time.now
        post "/posts/post:a.b.c", :post => {:document => {}, :occurrences => {:due => [timestamp.iso8601]}}
        Post.first.occurrences['due'].size.should eq 1
        Post.first.occurrences['due'].first.should be_within(1.0).of(timestamp)
      end
    end

    describe "GET /posts/:uid" do

      it "can retrieve a document" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'})
        get "/posts/#{p.uid}"
        result = JSON.parse(last_response.body)['post']
        result['uid'].should eq "post:a.b.c$#{p.id}"
        result['created_by'].should eq 1
        result['document']['title'].should eq "Hello spaceboy"
      end

      it "retrieves a tagged document" do
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

      it "retrieves a list of documents" do
        10.times do |i|
          Post.create!(:uid => "post:a.b.c", :document => i.to_s)
        end
        posts = Post.limit(3).order('created_at desc').all
        get "/posts/#{[posts.map(&:uid), "post:does.not.exist$99999999"].flatten.join(',')}"
        result = JSON.parse(last_response.body)['posts']
        result.size.should eq 4
        result.first['post']['document'].should eq posts.first.document
        result.last['post'].should eq nil
      end

      it "retrieves a collection of documents" do
        10.times do |i|
          Post.create!(:uid => "post:a.b.c", :document => i.to_s)
        end
        Post.create!(:uid => "post:a.b.d", :document => "a")
        get "/posts/post:*"
        result = JSON.parse(last_response.body)
        result['posts'].size.should eq 11
        result['posts'].first['post']['document'].should eq 'a'
        result['posts'].last['post']['document'].should eq '0'

        get "/posts/post:a.b.c#{CGI.escape('|')}d"
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

      it "filters by creator" do
        Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => '1')
        Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => '2')
        get "/posts/*:*", :created_by => 1
        JSON.parse(last_response.body)['posts'].first['post']['document'].should eq '1'
        get "/posts/*:*", :created_by => 2
        JSON.parse(last_response.body)['posts'].first['post']['document'].should eq '2'
      end

      it "filters on klass path" do
        post "/posts/post.blog:a.b", {:post => {:document => {content: "1"}}}
        post "/posts/post.comment:a.b.c", {:post => {:document => {content: "2"}}}
        post "/posts/post.comment:a.b.c", {:post => {:document => {content: "3"}}}
        get "/posts/*:*", :klass => "post.blog"
        JSON.parse(last_response.body)['posts'].size.should eq 1
        get "/posts/*:*", :klass => "post.comment"
        JSON.parse(last_response.body)['posts'].size.should eq 2
        get "/posts/post.comment:*"
        JSON.parse(last_response.body)['posts'].size.should eq 2
        get "/posts/*:*", :klass => "post.comment, post.blog"
        JSON.parse(last_response.body)['posts'].size.should eq 3
      end

      it "pages through documents" do
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

    describe "DELETE /posts/:uid" do

      it "deletes a document and removes it from cache" do
        post = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => '1', :created_by => 1337)
        get "/posts/#{post.uid}"
        last_response.status.should be 200
        delete "/posts/#{post.uid}"
        last_response.status.should be 204
        get "/posts/#{post.uid}"
        last_response.status.should be 404
      end

      it "cannot delete someone elses document" do
        post = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => '1', :created_by => 666)
        delete "/posts/#{post.uid}"
        last_response.status.should be 403
      end
    end

    describe "POST /posts/:uid/undelete" do

      it "cannot undelete a document" do
        post = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => '1', :created_by => 1337, :deleted => true)
        post "/posts/#{post.uid}/undelete"
        last_response.status.should be 403
      end
    end

    describe "GET /posts/:uid/count" do

      it "counts" do
        20.times do |i|
          Post.create!(:uid => "post:a.b.c", :document => i.to_s)
        end
        10.times do |i|
          Post.create!(:uid => "post:a.c.c", :document => i.to_s)
        end
        get "/posts/post:a.b.*$*/count"
        JSON.parse(last_response.body)['count'].should eq 20
      end
    end
  end

  context "with a logged in god" do
    before :each do
      Pebblebed::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {:id=>1337, :god => true}))
    end

    it "can undelete a document" do
      post = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => '1', :created_by => 10)
      get "/posts/#{post.uid}"
      last_response.status.should eq 200
      delete "/posts/#{post.uid}"
      get "/posts/#{post.uid}"
      last_response.status.should eq 404
      post "/posts/#{post.uid}/undelete"
      last_response.status.should eq 200
      get "/posts/#{post.uid}"
      last_response.status.should eq 200
    end

    it "can update a document created by another user without modifying created_by field" do
      p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => "Hello spaceboy")
      post "/posts/#{p.uid}", :post => {:document => "hello nobody"}
      last_response.status.should eq 200
      result = JSON.parse(last_response.body)['post']
      result['created_by'].should eq 1
    end
  end

  context "with no current user" do
    before :each do
      Pebblebed::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {:id=>nil, :god => nil}))
    end

    it "can't create posts" do
      post "/posts/post:a.b.c", {:document => "hello nobody"}
      last_response.status.should eq 403
    end
  end
end
