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
      expect(result).to be_empty
    end

    it "cannot read unpublished documents" do
      Post.create!(:uid => "post:a.b.c", :created_by => another_identity.id, :document => {'text' => 'xyzzy'}, :restricted => false, :published => false)
      get "/posts/post:a.b.c"
      result = JSON.parse(last_response.body)['posts']
      expect(result).to be_empty
    end

    it "cannot read the sensitive field" do
      p = Post.create!(:uid => "post:a.b.c", :created_by => another_identity.id, :sensitive => {'secret_key' => 'foobarbaz'})
      get "/posts/#{p.uid}"
      result = JSON.parse(last_response.body)['post']
      expect(result['sensitive']).to be_nil
    end

    it "can read published documents" do
      post = Post.create!(:uid => "post:a.b.c", :created_by => another_identity.id, :document => {'text' => 'xyzzy'}, :restricted => false, :published => true)
      get "/posts/post:a.b.c"
      result = JSON.parse(last_response.body)['posts']
      expect(result.first['post']['uid']).to eq post.uid
    end

    it "can read the protected field" do
      post = Post.create!(:uid => "post:a.b.c", :protected => {:price => 42}, :created_by => another_identity.id, :document => {'text' => 'xyzzy'})
      get "/posts/post:a.b.c"
      result = JSON.parse(last_response.body)['posts']
      expect(result.first['post']['protected']['price']).to eq 42
    end

  end

  context "with a logged in identity" do
    before(:each) { user!(:realm => 'a') }

    describe "POST /posts/:uid" do

      it "creates a document" do
        post "/posts/post:a.b.c", :post => {:document => {content: "hello world", foo: {bar: nil}}}
        uid = JSON.parse(last_response.body)['post']['uid']
        get "/posts/#{uid}"
        expect(last_response.status).to eq 200
        expect(JSON.parse(last_response.body)['post']['document']).to eq ({"content"=>"hello world", "foo"=>{"bar"=>nil}})
      end

      it "creates a tagged document" do
        post "/posts/post:a.b.c", :post => {:document => {'text' => "taggable"}, :tags => "paris, texas∞, lamar_county"}
        expect(Post.first.tags.sort).to eq ['paris', 'texas', 'lamar_county'].sort
      end

      it "sets the restricted flag" do
        post "/posts/post:a.b.c", :post => {:document => {:title => "restricted document"}, :restricted => true}
        expect(Post.first.restricted).to eq true
      end

      it "sets the published flag" do
        post "/posts/post:a.b.c", :post => {:document => {:title => "restricted document"}, :published => true}
        expect(Post.first.published).to eq true
      end

      it "sets the published flag" do
        post "/posts/post:a.b.c", :post => {:document => {:title => "restricted document"}, :published => false}
        expect(Post.first.published).to eq false
      end

      it "the sensitive field can be set" do
        post "/posts/post:a.b.c", :post => {:sensitive => {:secret => "dont tell"}}
        expect(Post.first.sensitive['secret']).to eq 'dont tell'
      end

      it "is unable to create a post on behalf of someone else" do
        post "/posts/post:a.b.c", :post => {:document => {:title => "spoofed document"}, :created_by => 666}
        expect(Post.first.created_by).to eq 1
      end

      it "is unable to create a post with protected content" do
        post "/posts/post:a.b.c", :post => {:protected=>{:a => '1'}, :document => {:title => 'document'}}
        expect(Post.first.protected).to eq({})
      end

      it "is unable to update a post with protected content" do
        p = Post.create!(:uid => 'post:a.b.c', :document => {:title => 'Hello spaceboy'}, :created_by => 1)
        post "/posts/#{p.uid}", :post => {:protected=>{:a => '1'}, :document => {:title => 'Hello pacman'}}
        expect(Post.first.protected).to eq({})
      end

      it "updates a document" do
        post "/posts/post:a.b.c", :post => {:document => {:title => 'Hello spaceboy'}}
        uid = JSON.parse(last_response.body)['post']['uid']
        post "/posts/#{uid}", :post => {:document =>  {:title => 'Hello universe'}}
        expect(Post.find_by_uid(uid).document['title']).to eq "Hello universe"
      end

      it "can't update a document created by another identity" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => another_identity.id, :document => {:title => 'Hello spaceboy'})
        post "/posts/#{p.uid}", :post => {:document => {:title => 'Hello nobody'}}
        expect(last_response.status).to eq 403
      end

      it "can't read the sensitive field of posts created by another identity" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => another_identity.id, :sensitive=> {:secret => 'shhhh'})
        get "/posts/#{p.uid}"
        expect(last_response.status).to eq 200
        expect(JSON.parse(last_response.body)['post']['secret']).to eq nil
      end

      it "can update a deleted document" do
        p = Post.create!(:uid => "post:a.b.c", :document => {'text' => '1'}, :created_by => 1, :deleted => true)
        post "/posts/#{p.uid}", :post => {:document => {'text' => '2'}}
        expect(last_response.status).to eq 200
      end

      it "can't update timestamps" do
        p = Post.create!(:uid => "post:a.b.c", :document => {'text' => '1'}, :created_by => 1)
        post "/posts/#{p.uid}", :post => {:document => {'text' => '2'}, :created_at => Time.new(0)}
        expect(last_response.status).to eq 200
        expect(Time.parse(JSON.parse(last_response.body)['post']['created_at']).to_s).to eq p.created_at.to_s
      end

      it "can post with external_id and avoid duplicates" do
        post "/posts/post:a.b.c", :post => {:document => {content: "hello world"}, :external_id => "unique"}
        expect(last_response.status).to eq 201
        # Posting again with same path and same external id will update the post
        post "/posts/post:a.b.c", :post => {:document => {content: "hello again"}, :external_id => "unique"}
        expect(last_response.status).to eq 200
        expect(Post.count).to eq 1
        expect(Post.first.document['content']).to eq "hello again"
        post "/posts/post:a.other.path", :post => {:document => {content: "hello mars"}, :external_id => "unique"}
        expect(last_response.status).to eq 409 # conflict because of other path
        expect(Post.first.document['content']).to eq "hello again"
        # Post to same path with different external_id creates a new document
        post "/posts/post:a.b.c", :post => {:document => {content: "hello again"}, :external_id => "other-unique"}
        expect(Post.count).to eq 2
        expect(last_response.status).to eq 201
      end

      it "can post to multiple paths" do
        post "/posts/post:a.b.c", :post => {:document => {}, :paths => ['a.b.secondary']}
        expect(Post.by_path('a.b.c').count).to eq 1
        expect(Post.by_path('a.b.secondary').count).to eq 1
        get "/posts/#{Post.first.uid}"
        expect(JSON.parse(last_response.body)['post']['paths'].sort).to eq ['a.b.secondary', 'a.b.c'].sort
      end

      it "can contain occurrences in time" do
        timestamp = Time.now
        post "/posts/post:a.b.c", :post => {:document => {}, :occurrences => {:due => [timestamp.iso8601]}}
        expect(Post.first.occurrences['due'].size).to eq 1
        expect(Post.first.occurrences['due'].first).to be_within(1.0).of(timestamp)
      end

      it "can post an external document" do
        post "/posts/post:a.b.c", :post => {:external_document => {:quick => "fox"}}
        expect(JSON.parse(last_response.body)['post']['document']['quick']).to eq 'fox'
      end

      it "allows for moderation of external documents" do
        post "/posts/post:a.b.c", :post => { :external_document => {
          :quick => "fox",
          :lazy => "dog"
        }}

        uid = JSON.parse(last_response.body)['post']['uid']

        put "/posts/#{uid}", :post => {:document => {:quick => "coyote"}}

        updated = JSON.parse(last_response.body)['post']
        expect(updated['document']['quick']).to eq 'coyote'
        expect(updated['document']['lazy']).to eq 'dog'
      end

      it "marks the post as conflicted if external document has been updated (i.e. imported) after moderation" do
        post "/posts/post:a.b.c", :post => { :document => {
          :quick => "coyote",
          :lazy => "dog"
        }}

        uid = JSON.parse(last_response.body)['post']['uid']

        put "/posts/#{uid}", :post => {:external_document => {:quick => "fox"}}

        updated = JSON.parse(last_response.body)['post']
        expect(updated['conflicted']).to be_truthy
        expect(updated['document']['quick']).to eq 'coyote' # Keeps the moderated version
        expect(updated['document']['lazy']).to eq 'dog'
      end

      it "protects against double postings" do
        post "/posts/post:a.b.c", :post => { :document => {
          :quick => "coyote",
          :lazy => "dog"
        }}
        expect(last_response.status).to eq 201
        post "/posts/post:a.b.c", :post => { :document => {
          :quick => "coyote",
          :lazy => "dog"
        }}
        expect(last_response.status).to eq 200
        expect(Post.count).to eq 1
      end
    end

    describe "PUT /posts/:uid" do
      it "returns 404 if the document doesn't exists" do
        put "/posts/post:a.b.c", :post => {:document => {:content => "hello world"}}
        expect(last_response.status).to eq 404
      end
      it "updates a document" do
        post "/posts/post:a.b.c", :post => {:document => {:title => 'Hello spaceboy'}}
        uid = JSON.parse(last_response.body)['post']['uid']
        put "/posts/#{uid}", :post => {:document =>  {:title => 'Hello universe'}}
        expect(Post.find_by_uid(uid).document['title']).to eq "Hello universe"
      end
    end

    describe "GET /posts/:uid" do
      describe "single uid queries" do
        it "can retrieve a document" do
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'})
          get "/posts/#{p.uid}"
          result = JSON.parse(last_response.body)['post']
          expect(result['uid']).to eq "post:a.b.c$#{p.id}"
          expect(result['created_by']).to eq 1
          expect(result['document']['title']).to eq "Hello spaceboy"
        end

        it "can retrieve a restricted document created by the current user" do
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'}, :restricted => true)
          get "/posts/#{p.uid}"
          result = JSON.parse(last_response.body)['post']
          expect(result['uid']).to eq "post:a.b.c$#{p.id}"
          expect(result['created_by']).to eq 1
          expect(result['document']['title']).to eq "Hello spaceboy"
        end

        it "can not retrieve a unpublished document created by the current user" do
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'}, :restricted => false, :published => false)
          get "/posts/#{p.uid}"
          expect(last_response.status).to eq 404
        end

        it "can not retrieve a restricted document created by another user" do
          p = Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {:title => 'Hello spaceboy'}, :restricted => true)
          get "/posts/#{p.uid}"
          expect(last_response.status).to eq 404
        end

        it "respects wildcard klass" do
          Post.create!(:uid => "post.card:a.b.c", :document => {:title => 'x'})
          Post.create!(:uid => "post.box:a.b.c", :document => {:title => 'x'})
          Post.create!(:uid => "post.man:a.b.c", :document => {:title => 'x'})
          get "/posts/post.card#{CGI.escape('|')}post.box:a.b.c"
          expect(JSON.parse(last_response.body)['posts'].count).to eq 2
        end

        context "with ?unpublished=include" do
          it "can retrieve an unpublished document created by the current user" do
            p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'}, :restricted => false, :published => false)
            get "/posts/#{p.uid}", :unpublished => 'include'

            result = JSON.parse(last_response.body)['post']
            expect(result['uid']).to eq p.uid
            expect(result['created_by']).to eq 1
          end

          it "can not retrieve an unpublished document created by another user" do
            p = Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {:title => 'Hello spaceboy'}, :published => false)
            get "/posts/#{p.uid}", :unpublished => 'include'
            expect(last_response.status).to eq 404
          end
        end

        context "with ?unpublished=only" do
          it "can retrieve an unpublished document created by the current user" do
            p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'}, :restricted => false, :published => false)
            p2 = Post.create!(:uid => "post:a.d.e", :created_by => 1, :document => {:title => 'Hello earthgirl'}, :restricted => false, :published => true)
            get "/posts/post:a.*", :unpublished => 'only'

            result = JSON.parse(last_response.body)['posts']
            expect(result.length).to eq 1
            expect(result[0]['post']['uid']).to eq p.uid
            expect(result[0]['post']['created_by']).to eq 1
          end

          it "can not retrieve an unpublished document created by another user" do
            p = Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {:title => 'Hello spaceboy'}, :published => false)
            get "/posts/#{p.uid}", :unpublished => 'only'
            expect(last_response.status).to eq 404
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
            expect(result['document']).to eq({'title' => 'Smurf'})
            expect(result['external_document']).to eq({'smurf_color' => 'blue'})
          end
        end

        describe "checking editable status in response" do
          it "returns true if identity is creator" do
            p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'})
            get "/posts/#{p.uid}"
            result = JSON.parse(last_response.body)['post']
            expect(result['may_edit']).to be_truthy
          end

          it "returns false unless identity is creator" do
            p = Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {:title => 'Hello spaceboy'})
            get "/posts/#{p.uid}"
            result = JSON.parse(last_response.body)['post']
            expect(result['may_edit']).to be_falsey
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
          expect(result.size).to eq 4
          expect(result.first['post']['document']).to eq posts.first.document
          expect(result.last['post']).to eq nil
        end

        it "retrieves a list of documents even if klass is omitted" do
          10.times do |i|
            Post.create!(:uid => "post:a.b.c", :document => {'text' => i.to_s})
          end
          post_ids = Post.all.map(&:id)
          get "/posts/*:a.*$#{(post_ids + [999999]).join(CGI.escape('|'))}"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 11
          expect(result.first['post']['id'].split('$').last.to_i).to eq post_ids.first
          expect(result.last['post']).to eq nil
        end

        it "returns an array if only a pipe is appended" do
          10.times do |i|
            Post.create!(:uid => "post:a.b.c", :document => {'text' => i.to_s})
          end
          post_id = Post.all.map(&:id).first
          get "/posts/*:a.*$#{post_id}#{CGI.escape("|")}"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 1
          expect(result.first['post']['id'].split('$').last.to_i).to eq post_id
        end

        it "can only read restricted posts created by current identity" do
          posts = []
          posts << Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => 'xyzzy'}, :restricted => true)
          posts << Post.create!(:uid => "post:a.b.d", :created_by => 2, :document => {'text' => 'zippo'}, :restricted => true)
          get "/posts/#{[posts.map(&:uid)].join(',')}"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 2
          expect(result[0]["post"]["uid"]).to eq posts[0].uid
          expect(result[1]["post"]).to be_nil
        end

        it "will not return unpublished posts created by current identity" do
          posts = []
          posts << Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => 'xyzzy'}, :published => false)
          posts << Post.create!(:uid => "post:a.b.d", :created_by => 2, :document => {'text' => 'zippo'}, :published => false)
          get "/posts/#{[posts.map(&:uid)].join(',')}"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 2
          expect(result[0]["post"]).to be_nil
          expect(result[1]["post"]).to be_nil
        end

        context "with unpublished=include" do

          it "will return unpublished posts created by current identity" do
            posts = [
              Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => 'xyzzy'}, :published => false),
              Post.create!(:uid => "post:a.b.d", :created_by => 1, :document => {'text' => 'zippo'}, :published => false)
            ]
            get "/posts/#{[posts.map(&:uid)].join(',')}", :unpublished => 'include'
            result = JSON.parse(last_response.body)['posts']
            expect(result.size).to eq 2
            expect(result[0]["post"]["uid"]).to eq posts[0].uid
            expect(result[1]["post"]["uid"]).to eq posts[1].uid
          end

          it "will return 'null' in place for unpublished posts created by other identities" do
            posts = [
                Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {'text' => 'xyzzy'}, :published => false),
                Post.create!(:uid => "post:a.b.d", :created_by => 1, :document => {'text' => 'zippo'}, :published => false)
            ]
            get "/posts/#{[posts.map(&:uid)].join(',')}", :unpublished => 'include'
            result = JSON.parse(last_response.body)['posts']
            expect(result.size).to eq 2
            expect(result[0]["post"]).to be_nil
            expect(result[1]["post"]["uid"]).to eq posts[1].uid
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
          expect(result['posts'].size).to eq 11
          expect(result['posts'].first['post']['document']).to eq('text' => 'a')
          expect(result['posts'].last['post']['document']).to eq('text' => '0')

          get "/posts/post:a.b.c#{CGI.escape('|')}d"
          result = JSON.parse(last_response.body)
          expect(result['posts'].size).to eq 11
          expect(result['posts'].first['post']['document']).to eq('text' => 'a')
          expect(result['posts'].last['post']['document']).to eq('text' => '0')

          get "/posts/post:*", :limit => 2
          result = JSON.parse(last_response.body)
          expect(result['posts'].size).to eq 2
          expect(result['posts'].first['post']['document']).to eq('text' => 'a')
          expect(result['posts'].last['post']['document']).to eq('text' => '9')

          get "/posts/post:a.b.*"
          result = JSON.parse(last_response.body)
          expect(result['posts'].size).to eq 11

          get "/posts/post:a.b.d$*"
          result = JSON.parse(last_response.body)
          expect(result['posts'].size).to eq 1

          # this is not a collection, actually, since
          # realm and oid are both unambiguous
          post = Post.first
          get "/posts/post:a.*$#{post.id}"
          result = JSON.parse(last_response.body)
          expect(result['post']['document']).to eq post.document
        end

        it "retrieves a tagged document" do
          Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'})
          Post.create!(:uid => "post:a.b.c", :tags => ["paris", "texas", "lamar_county"], :document => {'text' => '2'})
          Post.create!(:uid => "post:a.b.c", :tags => ["lyon", "france"], :document => {'text' => '3'})
          get "/posts/post:*", :tags => "texas"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 1
          expect(result.first['post']['document']).to eq('text' => "2")

          get "/posts/post:*", :tags => "paris"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 2

          get "/posts/post:*", :tags => "texas, paris"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 1

          get "/posts/post:*", :tags => "lamar_county"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 1

          get "/posts/post:*", :tags => "lamar"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 0

          get "/posts/post:*", :tags => "county"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 0
        end

        it "retrieves a tagged document using tsqueries" do
          Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'})
          Post.create!(:uid => "post:a.b.c", :tags => ["paris", "texas", "lamar_county"], :document => {'text' => '2'})
          Post.create!(:uid => "post:a.b.c", :tags => ["lyon", "france"], :document => {'text' => '3'})

          get "/posts/post:*", :tags => "paris & !texas"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 1

          get "/posts/post:*", :tags => "paris & lamar_county"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 1

          get "/posts/post:*", :tags => "!paris"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 1

          get "/posts/post:*", :tags => "!nothing"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 3

          get "/posts/post:*", :tags => "'"
          expect(last_response.status).to eq(400)
        end

        it "can retrieve a document by external_id" do
          external_id = "pippi_232323"
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'}, :external_id => external_id)
          get "/posts/*", :external_id => external_id
          expect(last_response.status).to eq(200)
          result = JSON.parse(last_response.body)['post']
          expect(result['uid']).to eq "post:a.b.c$#{p.id}"
          expect(result['external_id']).to eq external_id
        end

        it "can retrieve a document by external_id and realm and klass" do
          external_id = "pippi_232323"
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'}, :external_id => external_id)
          get "/posts/post:a.*", :external_id => external_id
          expect(last_response.status).to eq(200)
          result = JSON.parse(last_response.body)['post']
          expect(result['uid']).to eq "post:a.b.c$#{p.id}"
          expect(result['external_id']).to eq external_id
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
          expect(JSON.parse(last_response.body)['posts'].first['post']['document']).to eq('text' => '1')
        end

        it "fails when attempting to sort by a non-existing attribute" do
          Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => '1'})
          get "/posts/*:*", :sort_by => :xyzzy
          expect(last_response.status).to eq(400)
        end

        it "filters by created_after" do
          now = Time.new(2013,8,10)
          yesterday = now - 3600*24
          Post.create!(:uid => "post:a.b.c", :created_at => now)
          Post.create!(:uid => "post:a.b.c", :created_at => yesterday)
          get "/posts/post:*", :created_after => yesterday.to_s
          expect(JSON.parse(last_response.body)['posts'].count).to eq 1
          get "/posts/post:*", :created_after => (yesterday - 10).to_s
          expect(JSON.parse(last_response.body)['posts'].count).to eq 2
        end

        it "filters by created_before" do
          now = Time.new(2013,8,10)
          yesterday = now - 3600*24
          Post.create!(:uid => "post:a.b.c", :created_at => now)
          Post.create!(:uid => "post:a.b.c", :created_at => yesterday)

          get "/posts/post:*", :created_before => now.to_s
          expect(JSON.parse(last_response.body)['posts'].count).to eq 1

          get "/posts/post:*", :created_before => (now + 10).to_s
          expect(JSON.parse(last_response.body)['posts'].count).to eq 2
        end

        it "filters by creator" do
          Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => '1'})
          Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {'text' => '2'})
          get "/posts/*:*", :created_by => 1
          expect(JSON.parse(last_response.body)['posts'].first['post']['document']).to eq('text' => '1')
          get "/posts/*:*", :created_by => 2
          expect(JSON.parse(last_response.body)['posts'].first['post']['document']).to eq('text' => '2')
        end

        it "filters on klass path" do
          post "/posts/post.blog:a.b", {:post => {:document => {content: "1"}}}
          post "/posts/post.comment:a.b.c", {:post => {:document => {content: "2"}}}
          post "/posts/post.comment:a.b.c", {:post => {:document => {content: "3"}}}
          get "/posts/*:*", :klass => "post.blog"
          expect(JSON.parse(last_response.body)['posts'].size).to eq 1
          get "/posts/*:*", :klass => "post.comment"
          expect(JSON.parse(last_response.body)['posts'].size).to eq 2
          get "/posts/post.comment:*"
          expect(JSON.parse(last_response.body)['posts'].size).to eq 2
          get "/posts/*:*", :klass => "post.comment, post.blog"
          expect(JSON.parse(last_response.body)['posts'].size).to eq 3
      end

        it "filters by occurrence" do
          time = Time.now
          Post.create!(:uid => "post:a.b.c", :occurrences => {:start_time => [time]})
          Post.create!(:uid => "post:a.b.c", :occurrences => {:strange_time => [time]})
          Post.create!(:uid => "post:x.y.z", :occurrences => {:start_time => [time]})
          get "/posts/*:*", :occurrence => {:label => 'start_time'}
          expect(JSON.parse(last_response.body)['posts'].size).to eq 2
          get "/posts/*:*", :occurrence => {:label => 'start_time', :from => time+1}
          expect(JSON.parse(last_response.body)['posts'].size).to eq 0
          get "/posts/*:*", :occurrence => {:label => 'start_time', :from => time-1}
          expect(JSON.parse(last_response.body)['posts'].size).to eq 2
          get "/posts/*:*", :occurrence => {:label => 'start_time', :to => time-1}
          expect(JSON.parse(last_response.body)['posts'].size).to eq 0
          get "/posts/*:*", :occurrence => {:label => 'start_time', :to => time+1}
          expect(JSON.parse(last_response.body)['posts'].size).to eq 2

          get "/posts/post:x.y.z", :occurrence => {:label => 'start_time'}
          expect(JSON.parse(last_response.body)['posts'].size).to eq 1
        end

        it "pages through documents" do
          20.times do |i|
            Post.create!(:uid => "post:a.b.c", :document => {'text' => i.to_s})
          end
          get "/posts/post:*", :limit => 10, :offset => 2
          result = JSON.parse(last_response.body)
          expect(result['posts'].size).to eq 10
          expect(result['posts'].first['post']['document']).to eq('text' => "17")
          expect(result['posts'].last['post']['document']).to eq('text' => "8")
          expect(result['pagination']['last_page']).to be_falsey
          expect(result['pagination']['limit']).to eq 10
          expect(result['pagination']['offset']).to eq 2

          get "/posts/post:*", :limit => 10, :offset => 15
          result = JSON.parse(last_response.body)
          expect(result['posts'].size).to eq 5
          expect(result['posts'].first['post']['document']).to eq('text' => "4")
          expect(result['posts'].last['post']['document']).to eq('text' => "0")
          expect(result['pagination']['last_page']).to be_truthy
          expect(result['pagination']['limit']).to eq 10
          expect(result['pagination']['offset']).to eq 15
        end

        it "will not retrieve unpublished posts created by other identities" do
          Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {'text' => 'zippo'}, :published => false)
          get "/posts/post:a.b.c$*"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 0
        end

        it "will not retrieve unpublished posts created by current identity" do
          Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => 'zippo'}, :published => false)
          get "/posts/post:a.b.c$*"
          result = JSON.parse(last_response.body)['posts']
          expect(result.size).to eq 0
        end

        context "with ?unpublished=include" do
          it "will not retrieve unpublished posts created by other identities" do
            Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {'text' => 'zippo'}, :published => false)
            get "/posts/post:a.b.c", :unpublished => 'include'
            result = JSON.parse(last_response.body)['posts']
            expect(result.size).to eq 0
          end
          it "will retrieve unpublished posts created by current identity" do
            Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => 'zippo'}, :published => false)
            get "/posts/post:a.b.c", :unpublished => 'include'
            result = JSON.parse(last_response.body)['posts']
            expect(result.size).to eq 1
          end
          it "will retrieve other published posts too" do
            Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => 'foo'}, :published => false)
            Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {'text' => 'bar'}, :published => true)
            Post.create!(:uid => "post:a.b.c", :created_by => 3, :document => {'text' => 'baz'}, :published => true)
            get "/posts/post:a.b.c", :unpublished => 'include'
            result = JSON.parse(last_response.body)['posts']
            expect(result.size).to eq 3
          end
        end
      end
    end

    describe "DELETE /posts/:uid" do

      it "deletes a document and removes it from cache" do
        post = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'}, :created_by => 1)
        get "/posts/#{post.uid}"
        expect(last_response.status).to be 200
        delete "/posts/#{post.uid}"
        expect(last_response.status).to be 204
        get "/posts/#{post.uid}"
        expect(last_response.status).to be 404
      end

      it "deletes a document by external id" do
        post = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'}, :created_by => 1, :external_id => "foo_1")
        get "/posts/#{post.uid}"
        expect(last_response.status).to be 200
        delete "/posts/post:a.b.c?external_id=foo_1"
        expect(last_response.status).to be 204
        get "/posts/#{post.uid}"
        expect(last_response.status).to be 404
      end

      it "cannot delete someone elses document" do
        post = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'}, :created_by => 666)
        delete "/posts/#{post.uid}"
        expect(last_response.status).to be 403
      end
    end

    describe "POST /posts/:uid/undelete" do

      it "cannot undelete a document" do
        post = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'}, :created_by => 1, :deleted => true)
        post "/posts/#{post.uid}/undelete"
        expect(last_response.status).to be 403
      end
      it "cannot undelete a document unless member of a access group" do
        post = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'}, :created_by => 1, :deleted => true)
        GroupLocation.allow_subtree(1, "a.b")
        GroupMembership.declare!(1,1)
        post "/posts/#{post.uid}/undelete"
        expect(last_response.status).to be 200
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
        expect(last_response.status).to eq 200
        get "/posts/#{other_deleted_post.uid}", :deleted => 'include'
        expect(last_response.status).to eq 404
      end

      it "may GET /posts/:uid-with-wildcards?delete=include if the posts are my own" do
        my_deleted_post; other_deleted_post
        get "/posts/post:a.*", :deleted => 'include'
        expect(last_response.status).to eq 200
        result = JSON.parse(last_response.body)
        expect(result['posts'].count).to eq 1
        expect(result['posts'].first['post']['uid']).to eq my_deleted_post.uid
      end

      it "may GET /posts/:uid/count?delete=include, but only my own posts" do
        my_deleted_post; other_deleted_post
        get "/posts/post:a.*/count", :deleted => 'include'
        expect(last_response.status).to eq 200
        result = JSON.parse(last_response.body)
        expect(result['count']).to eq 1
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
        expect(JSON.parse(last_response.body)['count']).to eq 20
      end
      it "counts only published posts" do
        3.times do |i|
          Post.create!(:uid => "post:a.b.c", :document => {'text' => i.to_s}, :published => true)
        end
        3.times do |i|
          Post.create!(:uid => "post:a.b.c", :document => {'text' => i.to_s}, :published => false)
        end
        get "/posts/post:a.b.*$*/count"
        expect(JSON.parse(last_response.body)['count']).to eq 3
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
          expect(JSON.parse(last_response.body)['count']).to eq 6
        end
        it "does not count other identities's unpublished posts" do
          3.times do |i|
            Post.create!(:uid => "post:a.b.c", :created_by => 2, :document => {'text' => "xyzzy #{i}"}, :published => false)
          end
          3.times do |i|
            Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'text' => "zippo #{i}"}, :published => false)
          end
          get "/posts/post:a.b.c$*/count", :unpublished => 'include'
          expect(JSON.parse(last_response.body)['count']).to eq 3
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

        expect(last_response.status).to eq 200
        p.reload
        expect(p.paths.to_a.sort).to eq(["a.b.c", "a.b.d"])
      end

      it "doesn't try to add a path twice" do
        p = Post.create!(:uid => "post:a.b.c", :tags => ["paris", "france"], :document => {'text' => '1'}, :created_by => 1)

        post "/posts/#{p.uid}/paths/a.b.d"
        post "/posts/#{p.uid}/paths/a.b.d"

        expect(last_response.status).to eq 200
        p.reload
        expect(p.paths.to_a.sort).to eq(["a.b.c", "a.b.d"])
      end
    end

    describe "POST /posts/:uid/tags/:tags" do
      it "adds tags" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1)

        post "/posts/#{p.uid}/tags/paris,france"

        p.reload
        expect(p.tags.sort).to eq(['france', 'paris'])
      end

      it "adds more tags" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :tags => ['paris'])

        post "/posts/#{p.uid}/tags/wine,france"

        p.reload
        expect(p.tags.sort).to eq(['france', 'paris', 'wine'])
      end

      it "doesn't add duplicates" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :tags => ['paris'])

        post "/posts/#{p.uid}/tags/wine,france,paris"

        p.reload
        expect(p.tags.sort).to eq(['france', 'paris', 'wine'])
      end
    end

    describe "PUT /posts/:uid/tags/:tags" do
      it "updates the tags" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :tags => ["paris", "france"])

        put "/posts/#{p.uid}/tags/promenades,vins"

        p.reload
        expect(p.tags).to eq(["promenades", "vins"])
      end
    end

    describe "DELETE /posts/:uid/tags/:tags" do
      it "deletes tags" do
        p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :tags => ["paris", "france", "wine"])

        delete "/posts/#{p.uid}/tags/france,wine"

        p.reload
        expect(p.tags).to eq(["paris"])
      end
    end

    describe "PUT /posts/:uid/touch" do
      it "touches the post" do
        created_at = Time.new(2010, 3, 14, 15, 9, 26)
        p = Post.create!(:uid => "post:a.b.c", :created_at => created_at, :updated_at => created_at, :created_by => 1)

        put "/posts/#{p.uid}/touch"
        result = JSON.parse(last_response.body)['post']
        expect(Time.parse(result['updated_at'])).to be_within(5.seconds).of(Time.now)
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
          expect(p.occurrences['due'].map(&:utc)).to eq([soft_deadline.utc])
        end

        it "creates multiple occurrences" do
          p = Post.create!(:uid => "post:a.b.c", :created_by => 1)
          post "/posts/#{p.uid}/occurrences/due", :at => [soft_deadline, hard_deadline]

          p.reload
          expect(p.occurrences['due'].sort).to eq([soft_deadline, hard_deadline])
        end

        it "adds an occurrence to an existing one" do
          p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [soft_deadline]}, :created_by => 1)
          post "/posts/#{p.uid}/occurrences/due", :at => hard_deadline

          p.reload
          expect(p.occurrences['due'].sort).to eq([soft_deadline, hard_deadline])
        end

        it "doesn't add a duplicate occurrence" do
          p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [soft_deadline]}, :created_by => 1)
          post "/posts/#{p.uid}/occurrences/due", :at => soft_deadline

          p.reload
          expect(p.occurrences['due']).to eq([soft_deadline])
        end
      end

      describe "DELETE /posts/:uid/occurrences/:event" do
        it "deletes all the occurrences of that type for the event" do
          p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [soft_deadline, hard_deadline]},
            :created_by => 1)

          delete "/posts/#{p.uid}/occurrences/due"
          p.reload

          expect(p.occurrences['due']).to eq([])
        end
      end

      describe "PUT /posts/:uid/occurrences/:event" do
        it "replaces events" do
          p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [soft_deadline, hard_deadline]},
            :created_by => 1)

          put "/posts/#{p.uid}/occurrences/due", :at => now
          p.reload

          expect(p.occurrences['due']).to eq([now])
        end
      end
    end
  end

  context "with a logged in god" do
    before(:each) { god!(:realm => 'a') }

    it "can undelete a document" do
      post = Post.create!(:uid => "post:a.b.c", :document => {'text' => '1'}, :created_by => another_identity.id)
      get "/posts/#{post.uid}"
      expect(last_response.status).to eq 200
      delete "/posts/#{post.uid}"
      expect(last_response.status).to eq 204
      get "/posts/#{post.uid}"
      expect(last_response.status).to eq 404
      post "/posts/#{post.uid}/undelete"
      expect(last_response.status).to eq 200
      get "/posts/#{post.uid}"
      expect(last_response.status).to eq 200
    end

    it "can read restricted documents" do
      Post.create!(:uid => "post:a.b.c", :created_by => another_identity, :document => {'text' => 'xyzzy'}, :restricted => true)
      get "/posts/post:a.b.c"
      result = JSON.parse(last_response.body)['posts']
      expect(result.size).to eq 1
    end

    it "can read sensitive fields in posts" do
      p = Post.create!(:uid => "post:a.b.c", :created_by => another_identity, :sensitive => {:secret_key => 'foobarbaz'})
      get "/posts/#{p.uid}"
      post = JSON.parse(last_response.body)['post']
      expect(post['sensitive']['secret_key']).to eq 'foobarbaz'
    end

    it "can read unpublished documents created by other identities" do
      Post.create!(:uid => "post:a.b.c", :created_by => another_identity, :document => {'text' => 'xyzzy'}, :restricted => true, :published => false)
      get "/posts/post:a.b.c", :unpublished => 'include'
      result = JSON.parse(last_response.body)['posts']
      expect(result.size).to eq 1
    end

    it "does not modify created_by when updating a document" do
      p = Post.create!(:uid => "post:a.b.c", :created_by => another_identity.id, :document => {'text' => "Hello spaceboy"})
      post "/posts/#{p.uid}", :post => {:document => {'text' => "hello nobody"}}
      expect(last_response.status).to eq 200
      result = JSON.parse(last_response.body)['post']
      expect(result['created_by']).to eq another_identity.id
    end

    it "can update created_at timestamp" do
      p = Post.create!(:uid => "post:a.b.c", :document => {'text' => '1'}, :created_by => 1)
      new_time = Time.new(2012, 1, 1, 11, 11, 11, '+00:00')
      post "/posts/#{p.uid}", :post => {:document => {'text' => '2'}, :created_at => new_time}
      expect(last_response.status).to eq 200
      expect(Time.parse(JSON.parse(last_response.body)['post']['created_at']).utc).to eq new_time.utc
    end

    it "can't update updated_at timestamp" do
      p = Post.create!(:uid => "post:a.b.c", :document => {'text' => '1'}, :created_by => 1)
      initial_updated_at = p.updated_at
      new_created_at = Time.new(2012, 1, 1)
      post "/posts/#{p.uid}", :post => {:document => {'text' => '2'}, :created_at => new_created_at}
      post "/posts/#{p.uid}", :post => {:document => {'text' => '3'}, :updated_at => new_created_at}
      current_updated_at = Time.parse(JSON.parse(last_response.body)['post']['updated_at'])
      expect(initial_updated_at.to_i <= current_updated_at.to_i).to eq true
    end

    it "is able to create a post on behalf of someone else" do
      post "/posts/post:a.b.c", :post => {:document => {:title => "spoofed document"}, :created_by => 666}
      expect(Post.first.created_by).to eq 666
    end

    it "is able to create a post with protected content" do
      post "/posts/post:a.b.c", :post => {:realm => 'a', :protected=>{:a => '1'}, :document => {:title => 'document'}}
      expect(last_response.status).to eq 201
    end

    it "is able to update a post with protected content" do
      p = Post.create!(:uid => 'post:a.b.c', :realm => 'a', :document => {:title => 'Hello spaceboy'})
      post "/posts/#{p.uid}", :post => {:protected=>{:a => '1'}, :document => {:title => 'Hello pacman'}}
      expect(last_response.status).to eq 200
    end

  end
end
