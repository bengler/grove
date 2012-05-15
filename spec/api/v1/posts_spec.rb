require 'spec_helper'

describe "API v1 posts" do
  include Rack::Test::Methods

  def app
    GroveV1
  end

  user_endpoints = [
    {:method => :post, :endpoint => '/posts/post:a.b.c'},
    {:method => :post, :endpoint => '/posts/post:a.b.c$1/paths/a.b.d'},
    {:method => :delete, :endpoint => '/posts/post:a.b.c$1/paths/a.b.d'},
    {:method => :post, :endpoint => '/posts/post:a.b.c$1/occurrences/due'},
    {:method => :delete, :endpoint => '/posts/post:a.b.c$1/occurrences/due'},
    {:method => :put, :endpoint => '/posts/post:a.b.c$1/occurrences/due'},
    {:method => :put, :endpoint => '/posts/post:a.b.c$1/touch'},
    {:method => :put, :endpoint => '/posts/post:a.b.c$1/tags/:tags'}
  ]

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

      it "sets the restricted flag" do
        post "/posts/post:a.b.c", :post => {:document => "restricted document", :restricted => true}
        Post.first.restricted.should eq true
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

      it "can't update a deleted document" do
        p = Post.create!(:uid => "post:a.b.c", :document => '1', :created_by => 1337, :deleted => true)
        post "/posts/#{p.uid}", :post => {:document => '2'}
        last_response.status.should eq 404
      end

      it "can't update a deleted external document" do
        p = Post.create!(:uid => "post:a.b.c", :document => '1', :created_by => 1337, :deleted => true, :external_id => '123')
        post "/posts/#{p.uid}", :post => {:document => '2', :external_id => '123'}
        last_response.status.should eq 404
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

    describe "PUT /posts/:uid" do
      it "returns 404 if the document doesn't exists" do
        put "/posts/post:a.b.c", :post => {:document => {content: "hello world"}}
        last_response.status.should eq 404
      end
      it "updates a document" do
        post "/posts/post:a.b.c", :post => {:document => {:title => 'Hello spaceboy'}}
        uid = JSON.parse(last_response.body)['post']['uid']
        put "/posts/#{uid}", :post => {:document =>  {:title => 'Hello universe'}}
        Post.find_by_uid(uid).document['title'].should eq "Hello universe"
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
        result['post']['document'].should eq post.document
      end

      it "filters by creator" do
        Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => '1')
        Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => '2')
        get "/posts/*:*", :created_by => 1
        JSON.parse(last_response.body)['posts'].first['post']['document'].should eq '1'
        get "/posts/*:*", :created_by => 2
        JSON.parse(last_response.body)['posts'].first['post']['document'].should eq '2'
      end

      it "filters by external_id" do
        Post.create!(:uid => "post:a.b.c", :external_id => 'abc', :document => '1')
        Post.create!(:uid => "post:a.b.c", :external_id => 'pqr', :document => '2')
        get "/posts/*:*", :external_id => 'abc'
        JSON.parse(last_response.body)['posts'].first['post']['document'].should eq '1'
        get "/posts/*:*", :external_id => 'pqr'
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

      it "can read restricted posts created by current user" do
        post = Post.create!(:uid => "post:a.b.c", :created_by => 1337, :document => 'xyzzy', :restricted => true)
        2.times do |i|
          Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => i.to_s, :restricted => true)
        end
        posts = Post.limit(3).order('created_at asc').all
        get "/posts/#{[posts.map(&:uid)].join(',')}"
        result = JSON.parse(last_response.body)['posts']
        result.size.should eq 3
        result[0]["post"]["uid"].should eq post.uid
        result[1]["post"].should be_nil
        result[2]["post"].should be_nil
      end

      describe "checking editable status in response" do

        it "returns true if identity is creator" do
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1337, :document => {:title => 'Hello spaceboy'})
          get "/posts/#{p.uid}"
          result = JSON.parse(last_response.body)['post']
          result['may_edit'].should be_true
        end

        it "returns false unless identity is creator" do
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'})
          get "/posts/#{p.uid}"
          result = JSON.parse(last_response.body)['post']
          result['may_edit'].should be_false
        end

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

    describe "POST /posts/:uid/paths/:path" do
      it "adds a path" do
        p = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => '1', :created_by => 10)

        post "/posts/#{p.uid}/paths/a.b.d"

        last_response.status.should eq 200
        p.reload
        p.paths.to_a.sort.should eq(["a.b.c", "a.b.d"])
      end
    end

    describe "POST /posts/:uid/tags/:tags" do
      it "adds tags" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1337)

        post "/posts/#{p.uid}/tags/paris,france"

        p.reload
        p.tags.sort.should eq(['france', 'paris'])
      end

      it "adds more tags" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1337, :tags => ['paris'])

        post "/posts/#{p.uid}/tags/wine,france"

        p.reload
        p.tags.sort.should eq(['france', 'paris', 'wine'])
      end

      it "doesn't add duplicates" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1337, :tags => ['paris'])

        post "/posts/#{p.uid}/tags/wine,france,paris"

        p.reload
        p.tags.sort.should eq(['france', 'paris', 'wine'])
      end
    end

    describe "PUT /posts/:uid/tags/:tags" do
      it "updates the tags" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1337, :tags => ["paris", "france"])

        put "/posts/#{p.uid}/tags/promenades,vins"

        p.reload
        p.tags.should eq(["promenades", "vins"])
      end
    end

    describe "DELETE /posts/:uid/tags/:tags" do
      it "deletes tags" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1337, :tags => ["paris", "france", "wine"])

        delete "/posts/#{p.uid}/tags/france,wine"

        p.reload
        p.tags.should eq(["paris"])
      end
    end

    describe "PUT /posts/:uid/touch" do
      it "touches the post" do
        created_at = Time.new(2010, 3, 14, 15, 9, 26)
        p = Post.create!(:uid => "post:a.b.c", :created_at => created_at, :updated_at => created_at, :created_by => 1337)

        put "/posts/#{p.uid}/touch"
        result = JSON.parse(last_response.body)['post']
        Time.parse(result['updated_at']).should be_within(5.seconds).of(Time.now)
      end
    end

    describe "patching occurrences" do
      let(:now) { Time.new(2012, 1, 1, 11, 11, 11) }
      let(:soft_deadline) { Time.new(2012, 2, 7, 18, 28, 18) }
      let(:hard_deadline) { Time.new(2012, 3, 14, 15, 9, 26) }

      describe "POST /posts/:uid/occurrences/:event" do
        it "creates an occurrence" do
          p = Post.create!(:uid => "post:a.b.c")
          post "/posts/#{p.uid}/occurrences/due", :at => soft_deadline

          p.reload
          p.occurrences['due'].should eq([soft_deadline])
        end

        it "creates multiple occurrences" do
          p = Post.create!(:uid => "post:a.b.c")
          post "/posts/#{p.uid}/occurrences/due", :at => [soft_deadline, hard_deadline]

          p.reload
          p.occurrences['due'].sort.should eq([soft_deadline, hard_deadline])
        end

        it "adds an occurrence to an existing one" do
          p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [soft_deadline]})
          post "/posts/#{p.uid}/occurrences/due", :at => hard_deadline

          p.reload
          p.occurrences['due'].sort.should eq([soft_deadline, hard_deadline])
        end

        it "doesn't add a duplicate occurrence" do
          p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [soft_deadline]})
          post "/posts/#{p.uid}/occurrences/due", :at => soft_deadline

          p.reload
          p.occurrences['due'].should eq([soft_deadline])
        end
      end

      describe "DELETE /posts/:uid/occurrences/:event" do
        it "deletes the specified occurrence" do
          p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [soft_deadline, hard_deadline]})

          delete "/posts/#{p.uid}/occurrences/due", :at => soft_deadline
          p.reload

          p.occurrences['due'].should eq([hard_deadline])
        end

        it "deletes all the specified occurrences" do
          p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [soft_deadline, hard_deadline, now]})

          delete "/posts/#{p.uid}/occurrences/due", :at => [soft_deadline, hard_deadline]
          p.reload

          p.occurrences['due'].should eq([now])
        end

        it "deletes all the occurrences for the event" do
          p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [soft_deadline, hard_deadline]})

          delete "/posts/#{p.uid}/occurrences/due"
          p.reload

          p.occurrences['due'].should eq([])
        end
      end

      describe "PUT /posts/:uid/occurrences/:event" do
        it "replaces events" do
          p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [soft_deadline, hard_deadline]})

          put "/posts/#{p.uid}/occurrences/due", :at => now
          p.reload

          p.occurrences['due'].should eq([now])
        end
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

    it "can read restricted documents" do
      Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => 'xyzzy', :restricted => true)
      get "/posts/post:a.b.c"
      result = JSON.parse(last_response.body)['posts']
      result.size.should eq 1
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
      Pebblebed::Connector.any_instance.stub(:checkpoint).and_return(DeepStruct.wrap(:me => {}))
    end

    describe "has no access to user endpoints" do
      user_endpoints.each do |forbidden|
        it "fails to #{forbidden[:method]} #{forbidden[:endpoint]}" do
          self.send(forbidden[:method], forbidden[:endpoint])
          last_response.status.should eq(403)
        end
      end
    end

    it "cannot read restricted documents" do
      Post.create!(:uid => "post:a.b.c", :created_by => 3, :document => 'xyzzy', :restricted => true)
      get "/posts/post:a.b.c"
      result = JSON.parse(last_response.body)['posts']
      result.size.should eq 0
    end

  end
end
