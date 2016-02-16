# encoding: utf-8
require 'spec_helper'

describe "API v1 posts" do
  include Rack::Test::Methods
  include Pebblebed::RSpecHelper

  def app
    GroveV1.set :disable_callbacks => true
    GroveV1
  end

  context "with no current identity" do
    before(:each) { guest! }

    it "cannot read restricted documents" do
      Post.create!(:uid => "post:a.b.c", :created_by => another_identity.id, :document => {'text' => 'xyzzy'}, :restricted => true)
      get "/posts/post:a.b.c"
      result = JSON.parse(last_response.body)['posts']
      result.should be_empty
    end

    it "cannot read unpublished documents" do
      Post.create!(:uid => "post:a.b.c", :created_by => another_identity.id, :document => {'text' => 'xyzzy'}, :restricted => false, :published => false)
      get "/posts/post:a.b.c"
      result = JSON.parse(last_response.body)['posts']
      result.should be_empty
    end

    it "cannot read the sensitive field" do
      p = Post.create!(:uid => "post:a.b.c", :created_by => another_identity.id, :sensitive => {'secret_key' => 'foobarbaz'})
      get "/posts/#{p.uid}"
      result = JSON.parse(last_response.body)['post']
      result['sensitive'].should be_nil
    end

    it "can read published documents" do
      post = Post.create!(:uid => "post:a.b.c", :created_by => another_identity.id, :document => {'text' => 'xyzzy'}, :restricted => false, :published => true)
      get "/posts/post:a.b.c"
      result = JSON.parse(last_response.body)['posts']
      result.first['post']['uid'].should eq post.uid
    end

    it "can read the protected field" do
      post = Post.create!(:uid => "post:a.b.c", :protected => {:price => 42}, :created_by => another_identity.id, :document => {'text' => 'xyzzy'})
      get "/posts/post:a.b.c"
      result = JSON.parse(last_response.body)['posts']
      result.first['post']['protected']['price'].should eq 42
    end

  end

  context "with a logged in identity" do
    before(:each) { user!(:realm => 'a') }

    describe "POST /posts/:uid" do

      it "creates a document" do
        post "/posts/post:a.b.c", :post => {:document => {content: "hello world"}}
        uid = JSON.parse(last_response.body)['post']['uid']
        Post.find_by_uid(uid).document['content'].should eq "hello world"
      end

      it "creates a tagged document" do
        post "/posts/post:a.b.c", :post => {:document => {'text' => "taggable"}, :tags => "paris, texas∞, lamar_county"}
        Post.first.tags.sort.should eq ['paris', 'texas', 'lamar_county'].sort
      end

      it "sets the restricted flag" do
        post "/posts/post:a.b.c", :post => {:document => {:title => "restricted document"}, :restricted => true}
        Post.first.restricted.should eq true
      end

      it "sets the published flag" do
        post "/posts/post:a.b.c", :post => {:document => {:title => "restricted document"}, :published => true}
        Post.first.published.should eq true
      end

      it "sets the published flag" do
        post "/posts/post:a.b.c", :post => {:document => {:title => "restricted document"}, :published => false}
        Post.first.published.should eq false
      end

      it "the sensitive field can be set" do
        post "/posts/post:a.b.c", :post => {:sensitive => {:secret => "dont tell"}}
        Post.first.sensitive['secret'].should eq 'dont tell'
      end

      it "is unable to create a post on behalf of someone else" do
        post "/posts/post:a.b.c", :post => {:document => {:title => "spoofed document"}, :created_by => 666}
        Post.first.created_by.should eq 1
      end

      it "is unable to create a post with protected content" do
        post "/posts/post:a.b.c", :post => {:protected=>{:a => '1'}, :document => {:title => 'document'}}
        Post.first.protected.should eq({})
      end

      it "is unable to update a post with protected content" do
        p = Post.create!(:uid => 'post:a.b.c', :document => {:title => 'Hello spaceboy'}, :created_by => 1)
        post "/posts/#{p.uid}", :post => {:protected=>{:a => '1'}, :document => {:title => 'Hello pacman'}}
        Post.first.protected.should eq({})
      end

      it "updates a document" do
        post "/posts/post:a.b.c", :post => {:document => {:title => 'Hello spaceboy'}}
        uid = JSON.parse(last_response.body)['post']['uid']
        post "/posts/#{uid}", :post => {:document =>  {:title => 'Hello universe'}}
        Post.find_by_uid(uid).document['title'].should eq "Hello universe"
      end

      it "can't update a document created by another identity" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => another_identity.id, :document => {:title => 'Hello spaceboy'})
        post "/posts/#{p.uid}", :post => {:document => {:title => 'Hello nobody'}}
        last_response.status.should eq 403
      end

      it "can't read the sensitive field of posts created by another identity" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => another_identity.id, :sensitive=> {:secret => 'shhhh'})
        get "/posts/#{p.uid}"
        last_response.status.should eq 200
        JSON.parse(last_response.body)['post']['secret'].should eq nil
      end

      it "can update a deleted document" do
        p = Post.create!(:uid => "post:a.b.c", :document => {'text' => '1'}, :created_by => 1, :deleted => true)
        post "/posts/#{p.uid}", :post => {:document => {'text' => '2'}}
        last_response.status.should eq 200
      end

      it "can't update timestamps" do
        p = Post.create!(:uid => "post:a.b.c", :document => {'text' => '1'}, :created_by => 1)
        post "/posts/#{p.uid}", :post => {:document => {'text' => '2'}, :created_at => Time.new(0)}
        last_response.status.should eq 200
        Time.parse(JSON.parse(last_response.body)['post']['created_at']).to_s.should eq p.created_at.to_s
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

      it "can post an external document" do
        post "/posts/post:a.b.c", :post => {:external_document => {:quick => "fox"}}
        JSON.parse(last_response.body)['post']['document']['quick'].should eq 'fox'
      end

      it "allows for moderation of external documents" do
        post "/posts/post:a.b.c", :post => { :external_document => {
          :quick => "fox",
          :lazy => "dog"
        }}

        uid = JSON.parse(last_response.body)['post']['uid']

        put "/posts/#{uid}", :post => {:document => {:quick => "coyote"}}

        updated = JSON.parse(last_response.body)['post']
        updated['document']['quick'].should eq 'coyote'
        updated['document']['lazy'].should eq 'dog'
      end

      it "marks the post as conflicted if external document has been updated (i.e. imported) after moderation" do
        post "/posts/post:a.b.c", :post => { :document => {
          :quick => "coyote",
          :lazy => "dog"
        }}

        uid = JSON.parse(last_response.body)['post']['uid']

        put "/posts/#{uid}", :post => {:external_document => {:quick => "fox"}}

        updated = JSON.parse(last_response.body)['post']
        updated['conflicted'].should be_true
        updated['document']['quick'].should eq 'coyote' # Keeps the moderated version
        updated['document']['lazy'].should eq 'dog'
      end

      it "protects against double postings" do
        post "/posts/post:a.b.c", :post => { :document => {
          :quick => "coyote",
          :lazy => "dog"
        }}
        last_response.status.should eq 201
        post "/posts/post:a.b.c", :post => { :document => {
          :quick => "coyote",
          :lazy => "dog"
        }}
        last_response.status.should eq 200
        Post.count.should eq 1
      end
    end

    describe "PUT /posts/:uid" do
      it "returns 404 if the document doesn't exists" do
        put "/posts/post:a.b.c", :post => {:document => {:content => "hello world"}}
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
      describe "single uid queries" do
        it "can retrieve a document" do
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'})
          get "/posts/#{p.uid}"
          result = JSON.parse(last_response.body)['post']
          result['uid'].should eq "post:a.b.c$#{p.id}"
          result['created_by'].should eq 1
          result['document']['title'].should eq "Hello spaceboy"
        end

        it "can retrieve a restricted document created by the current user" do
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'}, :restricted => true)
          get "/posts/#{p.uid}"
          result = JSON.parse(last_response.body)['post']
          result['uid'].should eq "post:a.b.c$#{p.id}"
          result['created_by'].should eq 1
          result['document']['title'].should eq "Hello spaceboy"
        end

        it "can not retrieve a unpublished document created by the current user" do
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'}, :restricted => false, :published => false)
          get "/posts/#{p.uid}"
          last_response.status.should eq 404
        end

        it "can not retrieve a restricted document created by another user" do
          p = Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {:title => 'Hello spaceboy'}, :restricted => true)
          get "/posts/#{p.uid}"
          last_response.status.should eq 404
        end

        it "respects wildcard klass" do
          Post.create!(:uid => "post.card:a.b.c", :document => {:title => 'x'})
          Post.create!(:uid => "post.box:a.b.c", :document => {:title => 'x'})
          Post.create!(:uid => "post.man:a.b.c", :document => {:title => 'x'})
          get "/posts/post.card#{CGI.escape('|')}post.box:a.b.c"
          JSON.parse(last_response.body)['posts'].count.should eq 2
        end

        context "with ?unpublished=include" do
          it "can retrieve an unpublished document created by the current user" do
            p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'}, :restricted => false, :published => false)
            get "/posts/#{p.uid}", :unpublished => 'include'

            result = JSON.parse(last_response.body)['post']
            result['uid'].should eq p.uid
            result['created_by'].should eq 1
          end

          it "can not retrieve an unpublished document created by another user" do
            p = Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {:title => 'Hello spaceboy'}, :published => false)
            get "/posts/#{p.uid}", :unpublished => 'include'
            last_response.status.should eq 404
          end
        end

        context "with ?unpublished=only" do
          it "can retrieve an unpublished document created by the current user" do
            p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'}, :restricted => false, :published => false)
            p2 = Post.create!(:uid => "post:a.d.e", :created_by => 1, :document => {:title => 'Hello earthgirl'}, :restricted => false, :published => true)
            get "/posts/post:a.*", :unpublished => 'only'

            result = JSON.parse(last_response.body)['posts']
            result.length.should eq 1
            result[0]['post']['uid'].should eq p.uid
            result[0]['post']['created_by'].should eq 1
          end

          it "can not retrieve an unpublished document created by another user" do
            p = Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {:title => 'Hello spaceboy'}, :published => false)
            get "/posts/#{p.uid}", :unpublished => 'only'
            last_response.status.should eq 404
          end
        end

        context 'with ?raw=true' do
          let :post do
            Post.create!(
              uid: "post:a.b.c",
              created_by: 1,
              document: {title: 'Smurf'},
              external_document: {smurf_color: 'blue'})
          end

          it 'returns raw post' do
            get "/posts/#{post.uid}", unpublished: :include, raw: true

            result = JSON.parse(last_response.body)['post']
            result['document'].should eq({'title' => 'Smurf'})
            result['external_document'].should eq({'smurf_color' => 'blue'})
          end
        end

        describe "checking editable status in response" do
          it "returns true if identity is creator" do
            p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'})
            get "/posts/#{p.uid}"
            result = JSON.parse(last_response.body)['post']
            result['may_edit'].should be_true
          end

          it "returns false unless identity is creator" do
            p = Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {:title => 'Hello spaceboy'})
            get "/posts/#{p.uid}"
            result = JSON.parse(last_response.body)['post']
            result['may_edit'].should be_false
          end
        end
      end

      describe "list queries" do
        it "retrieves a list of documents" do
          10.times do |i|
            Post.create!(:uid => "post:a.b.c", :document => {'text' => i.to_s})
          end
          posts = Post.limit(3).order('created_at desc').all
          get "/posts/#{[posts.map(&:uid), "post:a.does.not.exist$99999999"].flatten.join(',')}"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 4
          result.first['post']['document'].should eq posts.first.document
          result.last['post'].should eq nil
        end

        it "retrieves a list of documents even if klass is omitted" do
          10.times do |i|
            Post.create!(:uid => "post:a.b.c", :document => {'text' => i.to_s})
          end
          post_ids = Post.all.map(&:id)
          get "/posts/*:a.*$#{(post_ids + [999999]).join(CGI.escape('|'))}"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 11
          result.first['post']['id'].split('$').last.to_i.should eq post_ids.first
          result.last['post'].should eq nil
        end

        it "returns an array if only a pipe is appended" do
          10.times do |i|
            Post.create!(:uid => "post:a.b.c", :document => {'text' => i.to_s})
          end
          post_id = Post.all.map(&:id).first
          get "/posts/*:a.*$#{post_id}#{CGI.escape("|")}"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 1
          result.first['post']['id'].split('$').last.to_i.should eq post_id
        end

        it "can only read restricted posts created by current identity" do
          posts = []
          posts << Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => 'xyzzy'}, :restricted => true)
          posts << Post.create!(:uid => "post:a.b.d", :created_by => 2, :document => {'text' => 'zippo'}, :restricted => true)
          get "/posts/#{[posts.map(&:uid)].join(',')}"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 2
          result[0]["post"]["uid"].should eq posts[0].uid
          result[1]["post"].should be_nil
        end

        it "will not return unpublished posts created by current identity" do
          posts = []
          posts << Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => 'xyzzy'}, :published => false)
          posts << Post.create!(:uid => "post:a.b.d", :created_by => 2, :document => {'text' => 'zippo'}, :published => false)
          get "/posts/#{[posts.map(&:uid)].join(',')}"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 2
          result[0]["post"].should be_nil
          result[1]["post"].should be_nil
        end

        context "with unpublished=include" do
  
          it "will return unpublished posts created by current identity" do
            posts = [
              Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => 'xyzzy'}, :published => false),
              Post.create!(:uid => "post:a.b.d", :created_by => 1, :document => {'text' => 'zippo'}, :published => false)
            ]
            get "/posts/#{[posts.map(&:uid)].join(',')}", :unpublished => 'include'
            result = JSON.parse(last_response.body)['posts']
            result.size.should eq 2
            result[0]["post"]["uid"].should eq posts[0].uid
            result[1]["post"]["uid"].should eq posts[1].uid
          end

          it "will return 'null' in place for unpublished posts created by other identities" do
            posts = [
                Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {'text' => 'xyzzy'}, :published => false),
                Post.create!(:uid => "post:a.b.d", :created_by => 1, :document => {'text' => 'zippo'}, :published => false)
            ]
            get "/posts/#{[posts.map(&:uid)].join(',')}", :unpublished => 'include'
            result = JSON.parse(last_response.body)['posts']
            result.size.should eq 2
            result[0]["post"].should be_nil
            result[1]["post"]["uid"].should eq posts[1].uid
          end
        end
      end

      describe "collection queries" do
        it "retrieves a collection of documents" do
          10.times do |i|
            Post.create!(:uid => "post:a.b.c", :document => {'text' => i.to_s})
          end
          Post.create!(:uid => "post:a.b.d", :document => {'text' => "a"})
          get "/posts/post:*"
          result = JSON.parse(last_response.body)
          result['posts'].size.should eq 11
          result['posts'].first['post']['document'].should eq('text' => 'a')
          result['posts'].last['post']['document'].should eq('text' => '0')

          get "/posts/post:a.b.c#{CGI.escape('|')}d"
          result = JSON.parse(last_response.body)
          result['posts'].size.should eq 11
          result['posts'].first['post']['document'].should eq('text' => 'a')
          result['posts'].last['post']['document'].should eq('text' => '0')

          get "/posts/post:*", :limit => 2
          result = JSON.parse(last_response.body)
          result['posts'].size.should eq 2
          result['posts'].first['post']['document'].should eq('text' => 'a')
          result['posts'].last['post']['document'].should eq('text' => '9')

          get "/posts/post:a.b.*"
          result = JSON.parse(last_response.body)
          result['posts'].size.should eq 11

          get "/posts/post:a.b.d$*"
          result = JSON.parse(last_response.body)
          result['posts'].size.should eq 1

          # this is not a collection, actually, since
          # realm and oid are both unambiguous
          post = Post.first
          get "/posts/post:a.*$#{post.id}"
          result = JSON.parse(last_response.body)
          result['post']['document'].should eq post.document
        end

        it "retrieves a tagged document" do
          Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'})
          Post.create!(:uid => "post:a.b.c", :tags => ["paris", "texas", "lamar_county"], :document => {'text' => '2'})
          Post.create!(:uid => "post:a.b.c", :tags => ["lyon", "france"], :document => {'text' => '3'})
          get "/posts/post:*", :tags => "texas"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 1
          result.first['post']['document'].should eq('text' => "2")

          get "/posts/post:*", :tags => "paris"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 2

          get "/posts/post:*", :tags => "texas, paris"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 1

          get "/posts/post:*", :tags => "lamar_county"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 1

          get "/posts/post:*", :tags => "lamar"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 0

          get "/posts/post:*", :tags => "county"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 0
        end

        it "retrieves a tagged document using tsqueries" do
          Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'})
          Post.create!(:uid => "post:a.b.c", :tags => ["paris", "texas", "lamar_county"], :document => {'text' => '2'})
          Post.create!(:uid => "post:a.b.c", :tags => ["lyon", "france"], :document => {'text' => '3'})

          get "/posts/post:*", :tags => "paris & !texas"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 1

          get "/posts/post:*", :tags => "paris & lamar_county"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 1

          get "/posts/post:*", :tags => "!paris"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 1

          get "/posts/post:*", :tags => "!nothing"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 3

          get "/posts/post:*", :tags => "'"
          last_response.status.should == 400
        end

        it "can retrieve a document by external_id" do
          external_id = "pippi_232323"
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'}, :external_id => external_id)
          get "/posts/*", :external_id => external_id
          last_response.status.should == 200
          result = JSON.parse(last_response.body)['post']
          result['uid'].should eq "post:a.b.c$#{p.id}"
          result['external_id'].should eq external_id
        end

        it "can retrieve a document by external_id and realm and klass" do
          external_id = "pippi_232323"
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'}, :external_id => external_id)
          get "/posts/post:a.*", :external_id => external_id
          last_response.status.should == 200
          result = JSON.parse(last_response.body)['post']
          result['uid'].should eq "post:a.b.c$#{p.id}"
          result['external_id'].should eq external_id
        end

        it "sorts the result by a specified attribute" do
          time = Time.new(2014, 12, 24)
          post = {
              :uid => "post:a.b.c",
              :created_by => 1,
              :document => {'text' => '1'},
              :updated_at => time - 2
          }
          Post.create!(post)
          post[:document] = {'text' => '2'}
          post[:updated_at] = time
          Post.create!(post)
          get "/posts/*:*", :sort_by => :updated_at, :direction => 'ASC'
          JSON.parse(last_response.body)['posts'].first['post']['document'].should eq('text' => '1')
        end

        it "fails when attempting to sort by a non-existing attribute" do
          Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => '1'})
          get "/posts/*:*", :sort_by => :xyzzy
          last_response.status.should == 400
        end

        it "filters by created_after" do
          now = Time.new(2013,8,10)
          yesterday = now - 3600*24
          Post.create!(:uid => "post:a.b.c", :created_at => now)
          Post.create!(:uid => "post:a.b.c", :created_at => yesterday)
          get "/posts/post:*", :created_after => yesterday.to_s
          JSON.parse(last_response.body)['posts'].count.should eq 1
          get "/posts/post:*", :created_after => (yesterday - 10).to_s
          JSON.parse(last_response.body)['posts'].count.should eq 2
        end

        it "filters by created_before" do
          now = Time.new(2013,8,10)
          yesterday = now - 3600*24
          Post.create!(:uid => "post:a.b.c", :created_at => now)
          Post.create!(:uid => "post:a.b.c", :created_at => yesterday)

          get "/posts/post:*", :created_before => now.to_s
          JSON.parse(last_response.body)['posts'].count.should eq 1

          get "/posts/post:*", :created_before => (now + 10).to_s
          JSON.parse(last_response.body)['posts'].count.should eq 2
        end

        it "filters by creator" do
          Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => '1'})
          Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {'text' => '2'})
          get "/posts/*:*", :created_by => 1
          JSON.parse(last_response.body)['posts'].first['post']['document'].should eq('text' => '1')
          get "/posts/*:*", :created_by => 2
          JSON.parse(last_response.body)['posts'].first['post']['document'].should eq('text' => '2')
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

        it "filters by occurrence" do
          time = Time.now
          Post.create!(:uid => "post:a.b.c", :occurrences => {:start_time => [time]})
          Post.create!(:uid => "post:a.b.c", :occurrences => {:strange_time => [time]})
          Post.create!(:uid => "post:x.y.z", :occurrences => {:start_time => [time]})
          get "/posts/*:*", :occurrence => {:label => 'start_time'}
          JSON.parse(last_response.body)['posts'].size.should eq 2
          get "/posts/*:*", :occurrence => {:label => 'start_time', :from => time+1}
          JSON.parse(last_response.body)['posts'].size.should eq 0
          get "/posts/*:*", :occurrence => {:label => 'start_time', :from => time-1}
          JSON.parse(last_response.body)['posts'].size.should eq 2
          get "/posts/*:*", :occurrence => {:label => 'start_time', :to => time-1}
          JSON.parse(last_response.body)['posts'].size.should eq 0
          get "/posts/*:*", :occurrence => {:label => 'start_time', :to => time+1}
          JSON.parse(last_response.body)['posts'].size.should eq 2

          get "/posts/post:x.y.z", :occurrence => {:label => 'start_time'}
          JSON.parse(last_response.body)['posts'].size.should eq 1
        end

        it "pages through documents" do
          20.times do |i|
            Post.create!(:uid => "post:a.b.c", :document => {'text' => i.to_s})
          end
          get "/posts/post:*", :limit => 10, :offset => 2
          result = JSON.parse(last_response.body)
          result['posts'].size.should eq 10
          result['posts'].first['post']['document'].should eq('text' => "17")
          result['posts'].last['post']['document'].should eq('text' => "8")
          result['pagination']['last_page'].should be_false
          result['pagination']['limit'].should eq 10
          result['pagination']['offset'].should eq 2

          get "/posts/post:*", :limit => 10, :offset => 15
          result = JSON.parse(last_response.body)
          result['posts'].size.should eq 5
          result['posts'].first['post']['document'].should eq('text' => "4")
          result['posts'].last['post']['document'].should eq('text' => "0")
          result['pagination']['last_page'].should be_true
          result['pagination']['limit'].should eq 10
          result['pagination']['offset'].should eq 15
        end

        it "will not retrieve unpublished posts created by other identities" do
          Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {'text' => 'zippo'}, :published => false)
          get "/posts/post:a.b.c$*"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 0
        end

        it "will not retrieve unpublished posts created by current identity" do
          Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => 'zippo'}, :published => false)
          get "/posts/post:a.b.c$*"
          result = JSON.parse(last_response.body)['posts']
          result.size.should eq 0
        end

        context "with ?unpublished=include" do
          it "will not retrieve unpublished posts created by other identities" do
            Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {'text' => 'zippo'}, :published => false)
            get "/posts/post:a.b.c", :unpublished => 'include'
            result = JSON.parse(last_response.body)['posts']
            result.size.should eq 0
          end
          it "will retrieve unpublished posts created by current identity" do
            Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => 'zippo'}, :published => false)
            get "/posts/post:a.b.c", :unpublished => 'include'
            result = JSON.parse(last_response.body)['posts']
            result.size.should eq 1
          end
          it "will retrieve other published posts too" do
            Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => 'foo'}, :published => false)
            Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {'text' => 'bar'}, :published => true)
            Post.create!(:uid => "post:a.b.c", :created_by => 3, :document => {'text' => 'baz'}, :published => true)
            get "/posts/post:a.b.c", :unpublished => 'include'
            result = JSON.parse(last_response.body)['posts']
            result.size.should eq 3
          end
        end
      end
    end

    describe "DELETE /posts/:uid" do

      it "deletes a document and removes it from cache" do
        post = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'}, :created_by => 1)
        get "/posts/#{post.uid}"
        last_response.status.should be 200
        delete "/posts/#{post.uid}"
        last_response.status.should be 204
        get "/posts/#{post.uid}"
        last_response.status.should be 404
      end

      it "deletes a document by external id" do
        post = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'}, :created_by => 1, :external_id => "foo_1")
        get "/posts/#{post.uid}"
        last_response.status.should be 200
        delete "/posts/post:a.b.c?external_id=foo_1"
        last_response.status.should be 204
        get "/posts/#{post.uid}"
        last_response.status.should be 404
      end

      it "cannot delete someone elses document" do
        post = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'}, :created_by => 666)
        delete "/posts/#{post.uid}"
        last_response.status.should be 403
      end
    end

    describe "POST /posts/:uid/undelete" do

      it "cannot undelete a document" do
        post = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'}, :created_by => 1, :deleted => true)
        post "/posts/#{post.uid}/undelete"
        last_response.status.should be 403
      end
      it "cannot undelete a document unless member of a access group" do
        post = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'}, :created_by => 1, :deleted => true)
        GroupLocation.allow_subtree(1, "a.b")
        GroupMembership.declare!(1,1)
        post "/posts/#{post.uid}/undelete"
        last_response.status.should be 200
      end

    end

    describe "with deleted=include" do
      let :my_deleted_post do
        Post.create!(:uid => "post:a.b.c", :deleted => true, :created_by => 1)
      end
      let :other_deleted_post do
        Post.create!(:uid => "post:a.b.c", :deleted => true, :created_by => 666)
      end

      it "may GET /posts/:uid?deleted=include if the posts are my own" do
        get "/posts/#{my_deleted_post.uid}", :deleted => 'include'
        last_response.status.should eq 200
        get "/posts/#{other_deleted_post.uid}", :deleted => 'include'
        last_response.status.should eq 404
      end

      it "may GET /posts/:uid-with-wildcards?delete=include if the posts are my own" do
        my_deleted_post; other_deleted_post
        get "/posts/post:a.*", :deleted => 'include'
        last_response.status.should eq 200
        result = JSON.parse(last_response.body)
        result['posts'].count.should eq 1
        result['posts'].first['post']['uid'].should eq my_deleted_post.uid
      end

      it "may GET /posts/:uid/count?delete=include, but only my own posts" do
        my_deleted_post; other_deleted_post
        get "/posts/post:a.*/count", :deleted => 'include'
        last_response.status.should eq 200
        result = JSON.parse(last_response.body)
        result['count'].should eq 1
      end
    end

    describe "GET /posts/:uid/count" do

      it "counts" do
        20.times do |i|
          Post.create!(:uid => "post:a.b.c", :document => {'text' => i.to_s})
        end
        Post.create!(:uid => "post:a.b.c", :document => {'text' => "deleted"}, :deleted => true)
        10.times do |i|
          Post.create!(:uid => "post:a.c.c", :document => {'text' => i.to_s})
        end
        get "/posts/post:a.b.*$*/count"
        JSON.parse(last_response.body)['count'].should eq 20
      end
      it "counts only published posts" do
        3.times do |i|
          Post.create!(:uid => "post:a.b.c", :document => {'text' => i.to_s}, :published => true)
        end
        3.times do |i|
          Post.create!(:uid => "post:a.b.c", :document => {'text' => i.to_s}, :published => false)
        end
        get "/posts/post:a.b.*$*/count"
        JSON.parse(last_response.body)['count'].should eq 3
      end
      context "with ?unpublished=include" do
        before(:each) { user!(:realm => 'a') }
        it "counts current identitiy's unpublished posts" do
          3.times do |i|
            Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => "xyzzy #{i}"}, :published => false)
          end
          3.times do |i|
            Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => "zippo #{i}"}, :published => false)
          end
          get "/posts/post:a.b.c$*/count", :unpublished => 'include' 
          JSON.parse(last_response.body)['count'].should eq 6
        end
        it "does not count other identities's unpublished posts" do
          3.times do |i|
            Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {'text' => "xyzzy #{i}"}, :published => false)
          end
          3.times do |i|
            Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => "zippo #{i}"}, :published => false)
          end
          get "/posts/post:a.b.c$*/count", :unpublished => 'include' 
          JSON.parse(last_response.body)['count'].should eq 3
        end
      end
    end

    describe "GET /posts/:uid/tags" do

      before do
        Post.create!(
          uid: "post:a.b.c",
          document: {text: "blah"},
          tags: %w(one))
        Post.create!(
          uid: "post:a.b.c",
          document: {text: "blah"},
          tags: %w(one two))
        Post.create!(
          uid: "post:a.b.c",
          document: {text: "blah"},
          tags: %w(three))
      end

      context 'no matches' do
        it "returns empty hash" do
          get "/posts/post:x$*/tags"

          result = JSON.parse(last_response.body)
          expect(result).to include('tags')
          expect(result['tags']).to be_empty
        end
      end

      context 'with basic path' do
        it "returns tags" do
          get "/posts/post:a.b.*$*/tags"

          result = JSON.parse(last_response.body)
          expect(result).to include('tags')
          expect(result['tags']).to eq({
            'one' => 2,
            'two' => 1,
            'three' => 1,
          })
        end
      end

      context 'with single tag' do
        it "returns tags" do
          get "/posts/post:a.b.*$*/tags", {tags: "one"}

          result = JSON.parse(last_response.body)
          expect(result['tags']).to eq({
            'one' => 2,
            'two' => 1,
          })
        end
      end

      context 'with an "and" tag query' do
        it "returns tags" do
          get "/posts/post:a.b.*$*/tags", {tags: "one & two"}

          result = JSON.parse(last_response.body)
          expect(result['tags']).to eq({
            'one' => 1,
            'two' => 1
          })
        end
      end

      context 'with a list of tags' do
        it "returns tags" do
          get "/posts/post:a.b.*$*/tags", {tags: "one,two"}

          result = JSON.parse(last_response.body)
          expect(result['tags']).to eq({
            'one' => 1,
            'two' => 1
          })
        end
      end

      context 'with a list of tags as an array' do
        it "returns tags" do
          get "/posts/post:a.b.*$*/tags", {tags: %w(one two)}

          result = JSON.parse(last_response.body)
          expect(result['tags']).to eq({
            'one' => 1,
            'two' => 1
          })
        end
      end

      context 'with an "or" tag query' do
        it "returns tags" do
          get "/posts/post:a.b.*$*/tags", {tags: "one | two"}

          result = JSON.parse(last_response.body)
          expect(result['tags']).to eq({
            'one' => 2,
            'two' => 1
          })
        end
      end

    end

    describe "POST /posts/:uid/paths/:path" do
      it "adds a path" do
        p = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'}, :created_by => 1)

        post "/posts/#{p.uid}/paths/a.b.d"

        last_response.status.should eq 200
        p.reload
        p.paths.to_a.sort.should eq(["a.b.c", "a.b.d"])
      end

      it "doesn't try to add a path twice" do
        p = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'}, :created_by => 1)

        post "/posts/#{p.uid}/paths/a.b.d"
        post "/posts/#{p.uid}/paths/a.b.d"

        last_response.status.should eq 200
        p.reload
        p.paths.to_a.sort.should eq(["a.b.c", "a.b.d"])
      end
    end

    describe "POST /posts/:uid/tags/:tags" do
      it "adds tags" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1)

        post "/posts/#{p.uid}/tags/paris,france"

        p.reload
        p.tags.sort.should eq(['france', 'paris'])
      end

      it "adds more tags" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :tags => ['paris'])

        post "/posts/#{p.uid}/tags/wine,france"

        p.reload
        p.tags.sort.should eq(['france', 'paris', 'wine'])
      end

      it "doesn't add duplicates" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :tags => ['paris'])

        post "/posts/#{p.uid}/tags/wine,france,paris"

        p.reload
        p.tags.sort.should eq(['france', 'paris', 'wine'])
      end
    end

    describe "PUT /posts/:uid/tags/:tags" do
      it "updates the tags" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :tags => ["paris", "france"])

        put "/posts/#{p.uid}/tags/promenades,vins"

        p.reload
        p.tags.should eq(["promenades", "vins"])
      end
    end

    describe "DELETE /posts/:uid/tags/:tags" do
      it "deletes tags" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :tags => ["paris", "france", "wine"])

        delete "/posts/#{p.uid}/tags/france,wine"

        p.reload
        p.tags.should eq(["paris"])
      end
    end

    describe "PUT /posts/:uid/touch" do
      it "touches the post" do
        created_at = Time.new(2010, 3, 14, 15, 9, 26)
        p = Post.create!(:uid => "post:a.b.c", :created_at => created_at, :updated_at => created_at, :created_by => 1)

        put "/posts/#{p.uid}/touch"
        result = JSON.parse(last_response.body)['post']
        Time.parse(result['updated_at']).should be_within(5.seconds).of(Time.now)
      end
    end

    describe "patching occurrences" do
      let(:now) { Time.new(2012, 1, 1, 11, 11, 11, '+00:00') }
      let(:soft_deadline) { Time.new(2012, 2, 7, 18, 28, 18, '+00:00') }
      let(:hard_deadline) { Time.new(2012, 3, 14, 15, 9, 26, '+00:00') }

      describe "POST /posts/:uid/occurrences/:event" do
        it "creates an occurrence" do
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1)
          post "/posts/#{p.uid}/occurrences/due", :at => soft_deadline

          p.reload
          p.occurrences['due'].map(&:utc).should eq([soft_deadline.utc])
        end

        it "creates multiple occurrences" do
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1)
          post "/posts/#{p.uid}/occurrences/due", :at => [soft_deadline, hard_deadline]

          p.reload
          p.occurrences['due'].sort.should eq([soft_deadline, hard_deadline])
        end

        it "adds an occurrence to an existing one" do
          p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [soft_deadline]}, :created_by => 1)
          post "/posts/#{p.uid}/occurrences/due", :at => hard_deadline

          p.reload
          p.occurrences['due'].sort.should eq([soft_deadline, hard_deadline])
        end

        it "doesn't add a duplicate occurrence" do
          p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [soft_deadline]}, :created_by => 1)
          post "/posts/#{p.uid}/occurrences/due", :at => soft_deadline

          p.reload
          p.occurrences['due'].should eq([soft_deadline])
        end
      end

      describe "DELETE /posts/:uid/occurrences/:event" do
        it "deletes all the occurrences of that type for the event" do
          p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [soft_deadline, hard_deadline]},
            :created_by => 1)

          delete "/posts/#{p.uid}/occurrences/due"
          p.reload

          p.occurrences['due'].should eq([])
        end
      end

      describe "PUT /posts/:uid/occurrences/:event" do
        it "replaces events" do
          p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [soft_deadline, hard_deadline]},
            :created_by => 1)

          put "/posts/#{p.uid}/occurrences/due", :at => now
          p.reload

          p.occurrences['due'].should eq([now])
        end
      end
    end
  end

  context "with a logged in god" do
    before(:each) { god!(:realm => 'a') }

    it "can undelete a document" do
      post = Post.create!(:uid => "post:a.b.c", :document => {'text' => '1'}, :created_by => another_identity.id)
      get "/posts/#{post.uid}"
      last_response.status.should eq 200
      delete "/posts/#{post.uid}"
      last_response.status.should eq 204
      get "/posts/#{post.uid}"
      last_response.status.should eq 404
      post "/posts/#{post.uid}/undelete"
      last_response.status.should eq 200
      get "/posts/#{post.uid}"
      last_response.status.should eq 200
    end

    it "can read restricted documents" do
      Post.create!(:uid => "post:a.b.c", :created_by => another_identity, :document => {'text' => 'xyzzy'}, :restricted => true)
      get "/posts/post:a.b.c"
      result = JSON.parse(last_response.body)['posts']
      result.size.should eq 1
    end

    it "can read sensitive fields in posts" do
      p = Post.create!(:uid => "post:a.b.c", :created_by => another_identity, :sensitive => {:secret_key => 'foobarbaz'})
      get "/posts/#{p.uid}"
      post = JSON.parse(last_response.body)['post']
      post['sensitive']['secret_key'].should eq 'foobarbaz'
    end

    it "can read unpublished documents created by other identities" do
      Post.create!(:uid => "post:a.b.c", :created_by => another_identity, :document => {'text' => 'xyzzy'}, :restricted => true, :published => false)
      get "/posts/post:a.b.c", :unpublished => 'include'
      result = JSON.parse(last_response.body)['posts']
      result.size.should eq 1
    end

    it "does not modify created_by when updating a document" do
      p = Post.create!(:uid => "post:a.b.c", :created_by => another_identity.id, :document => {'text' => "Hello spaceboy"})
      post "/posts/#{p.uid}", :post => {:document => {'text' => "hello nobody"}}
      last_response.status.should eq 200
      result = JSON.parse(last_response.body)['post']
      result['created_by'].should eq another_identity.id
    end

    it "can update timestamps" do
      p = Post.create!(:uid => "post:a.b.c", :document => {'text' => '1'}, :created_by => 1)
      new_time = Time.new(2012, 1, 1, 11, 11, 11, '+00:00')
      post "/posts/#{p.uid}", :post => {:document => {'text' => '2'}, :created_at => new_time}
      last_response.status.should eq 200
      Time.parse(JSON.parse(last_response.body)['post']['created_at']).utc.should eq new_time.utc
    end

    it "is able to create a post on behalf of someone else" do
      post "/posts/post:a.b.c", :post => {:document => {:title => "spoofed document"}, :created_by => 666}
      Post.first.created_by.should eq 666
    end

    it "is able to create a post with protected content" do
      post "/posts/post:a.b.c", :post => {:realm => 'a', :protected=>{:a => '1'}, :document => {:title => 'document'}}
      last_response.status.should eq 201
    end

    it "is able to update a post with protected content" do
      p = Post.create!(:uid => 'post:a.b.c', :realm => 'a', :document => {:title => 'Hello spaceboy'})
      post "/posts/#{p.uid}", :post => {:protected=>{:a => '1'}, :document => {:title => 'Hello pacman'}}
      last_response.status.should eq 200
    end

  end
end
