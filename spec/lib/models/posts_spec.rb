require 'cache_key'
require 'cache_keychain'
require 'spec_helper'

describe Post do
  it "gets attached to a location" do
    p = Post.create!(:canonical_path => "area51.vaktmesterkontoret.forum1")
    p.locations.count.should eq 1
    p.locations.first.path.to_s.should eq "area51.vaktmesterkontoret.forum1"
    p.realm.should eq "area51"
  end

  it "can genereate an uid" do
    p = Post.create!(:canonical_path => "area51.vaktmesterkontoret.forum1")
    p.uid.should eq "post:area51.vaktmesterkontoret.forum1$#{p.id}"
  end

  it "can have a child klass" do
    p = Post.create!(:uid => "post.assignment:area51")
    p.uid.should eq("post.assignment:area51$#{p.id}")
  end

  it "can retrieve one by uid" do
    p1 = Post.create!(:canonical_path => "area51.vaktmesterkontoret.forum1", :document => {:text => "1"})
    p2 = Post.create!(:canonical_path => "area51.vaktmesterkontoret.forum2", :document => {:text => "2"})
    p3 = Post.create!(:canonical_path => "area51.vaktmesterkontoret.forum3", :document => {:text => "3"})
    Post.find_by_uid(p1.uid).document[:text].should eq '1'
    Post.find_by_uid(p2.uid).document[:text].should eq '2'
    Post.find_by_uid(p3.uid).document[:text].should eq '3'
    Post.find_by_uid("post:area51.vaktmesterkontoret.forumX$2").should be_nil
  end

  it "filters by realm" do
    uid = "post:area51.vaktmesterkontoret.forum1"
    p = Post.create!(:uid => uid)
    Post.create!(:uid => "post:oz.other.place")

    posts = Post.filtered_by('realm' => 'area51')
    posts.size.should eq(1)
    posts.first.uid.should eq(p.uid)
  end

  it "can assign realm, canonical_path by assigning uid" do
    p = Post.create!(:uid => "post:area51.vaktmesterkontoret.forum1")
    p.realm.should eq "area51"
    p.canonical_path.should eq "area51.vaktmesterkontoret.forum1"
  end

  it "can retrieve a collection of posts with a wildcard uid" do
    Post.create!(:uid => "post:area51.vaktemsterkontoret.forum1", :document => {:text => "1"})
    Post.create!(:uid => "post:area51.vaktemsterkontoret.forum1", :document => {:text => "2"})
    Post.create!(:uid => "post:area51.vaktemsterkontoret.forum1", :document => {:text => "3"})
    Post.create!(:uid => "post:area51.vaktemsterkontoret.forum2", :document => {:text => "4"})
    Post.create!(:uid => "post:area52.vaktemsterkontoret.forum2", :document => {:text => "5"})
    Post.by_uid("post:*").map(&:document).map{|document| document[:text]}.sort.should eq ['1', '2', '3', '4', '5']
    Post.by_uid("post:area51.*").map(&:document).map{|document| document[:text]}.sort.should eq ['1', '2', '3', '4']
    Post.by_uid("post:area51.vaktemsterkontoret.forum1").map(&:document).map{|document| document[:text]}.sort.should eq ['1', '2', '3']
    Post.by_uid("post:area51.vaktemsterkontoret.forum2").map(&:document).map{|document| document[:text]}.sort.should eq ['4']
  end

  it "has a fancy method to get a lot of posts with readthrough caching (memcached)" do
    doc1 = Post.create!(:uid => "post:area51.vaktemsterkontoret.forum1", :document => {:text => "1"})
    doc2 = Post.create!(:uid => "post:area51.vaktemsterkontoret.forum1", :document => {:text => "2"})
    posts = Post.cached_find_all_by_uid([doc1.uid, doc2.uid])
    posts.first.document[:text].should eq '1'
    # Have a look in the cache to verify that the documents got there
    post = JSON.parse($memcached.get(SchemaVersion.tag_key(doc1.cache_key)))
    post['document']['text'].should eq '1'
    # Verify that the order matches the request
    posts = Post.cached_find_all_by_uid([doc2.uid, doc1.uid])
    posts.first.document['text'].should eq '2'
    # Change the cached document to verify that it actually reads through the cache
    post = JSON.parse($memcached.get(SchemaVersion.tag_key(doc1.cache_key)))
    post['document'] = "sentinel"
    $memcached.set(SchemaVersion.tag_key(doc1.cache_key), post.to_json)
    posts = Post.cached_find_all_by_uid([doc1.uid])
    posts.first.document.should eq 'sentinel'
    # Delete one of the cached documents to verify that the finder can perform with only partial cache hits
    $memcached.delete(SchemaVersion.tag_key(doc1.cache_key))
    posts = Post.cached_find_all_by_uid([doc1.uid, doc2.uid])
    posts.first.document[:text].should eq '1'
    # Update one to verify that the cache is invalidated
    doc1.document = "watchdog"
    doc1.save!
    posts = Post.cached_find_all_by_uid([doc1.uid])
    posts.first.document.should eq 'watchdog'
  end

  it "knows how to handle non-existant posts when using cached_find_all_by_uid" do
    posts = Post.cached_find_all_by_uid(["post:out.of.this$1"])
    posts.should eq [nil]
  end

  it "does not try to retrieve wildcards from the cache" do
    ->{ Post.cached_find_all_by_uid(["post:with.wildcard.*"]) }.should raise_error ArgumentError
  end

  it "does not try to retrieve pipes from the cache" do
    ->{ Post.cached_find_all_by_uid(["post:with.pipes.a|b|c"]) }.should raise_error ArgumentError
  end

  it "can scope posts by tag" do
    Post.create!(:uid => "post:a.b.c", :tags => ["france", "paris"], :document => {:text => '1'})
    Post.create!(:uid => "post:a.b.c", :tags => ["capitals", "paris"], :document => {:text => '2'})
    Post.create!(:uid => "post:a.b.c", :tags => ["france", "lyon"], :document => {:text => '3'})
    Post.with_tags("paris").all.map(&:document).map{|document| document[:text]}.sort.should eq ['1', '2']
    Post.with_tags("france").all.map(&:document).map{|document| document[:text]}.sort.should eq ['1', '3']
    Post.with_tags(["france", "paris"]).all.map(&:document).map{|document| document[:text]}.sort.should eq ['1']
  end

  it "can put a post in several locations" do
    doc1 = Post.create!(:uid => "post:area51.vaktemsterkontoret.forum1", :document => {:text => "1"})
    Location.declare!("area51.vikarkontoret.forum1").posts << doc1
    Location.declare!("area51.vikarkontoret.forum2").posts << doc1
    Post.create!(:uid => "post:area51.somewhereelse.forum1", :document => {:text => "2"})
    Post.by_uid("post:area51.*").all.map(&:document).map{|document| document[:text]}.sort.should eq ['1', '2']
    Post.by_uid("post:highway61.*").count.should eq 0
    Post.by_uid("post:area51.vikarkontoret.*").first.document[:text].should eq '1'
  end

  it "will only find by uids that are fully constrained (with an oid)" do
    doc = Post.create!(:uid => "post:area51.vaktemsterkontoret.forum1", :document => {:text => "1"})
    Post.find_by_uid(doc.uid).should_not be_nil
    Post.find_by_uid("post:area51.vaktemsterkontoret.forum1").should be_nil
  end

  # TODO: This should be configurable
  it "sanitizes some fields if the content is json" do
    Post.create!(:uid => "post:a.b.c", :tags => ["france", "paris"], :document => {"text" => "<a><script>hei"})
    Post.first.document['text'].should eq "hei"
  end

  it 'atomically adds a path' do
    post = Post.create!(:uid => "post:a.b.c", :tags => ["france", "paris"], :document => {"text" => "<a><script>hei"})
    post.should_not_receive(:save)
    post.should_not_receive(:save!)

    post.add_path!("a.b.d")

    post.reload
    post.paths.to_a.sort.should eq(["a.b.c", "a.b.d"])
  end

  it 'atomically deletes a path' do
    post = Post.create!(:uid => "post:a.b.c", :tags => ["france", "paris"], :document => {"hello" => "spaceboy"})
    other_post = Post.create!(:uid => "post:a.b.c.d.e", :tags => ["wine", "dining"], :document => {"hello" => "cowgirl"})
    Location.declare!("a.b.d").posts << post
    Location.declare!("a.b.d").posts << other_post

    post.should_not_receive(:save)
    post.should_not_receive(:save!)

    post.remove_path!("a.b.d")

    post.reload
    other_post.reload

    post.paths.to_a.should eq(["a.b.c"])
    other_post.paths.to_a.sort.should eq(["a.b.c.d.e", "a.b.d"])
  end

  it "cannot delete the canonical path" do
    post = Post.create!(:uid => "post:a.b.c", :tags => ["france", "paris"], :document => {"text" => "<a><script>hei"})
    Location.declare!("a.b.d").posts << post

    ->{ post.remove_path!("a.b.c") }.should raise_error ArgumentError

    post.reload
    post.paths.to_a.sort.should eq(["a.b.c", "a.b.d"])
  end


  context "searching for restricted documents" do

    it "will fail without an identity" do
      identity = DeepStruct.wrap({})
      post = Post.create!(:uid => "post:a.b.c", :document => {:text => "xyzzy"}, :created_by => 1337, :restricted => true)
      Post.with_restrictions(identity).size.should eq 0
      post.visible_to?(identity).should eq false
    end

    it "will fail if identity is not the document creator" do
      identity = DeepStruct.wrap({:id => 1337, :god => false})
      post = Post.create!(:uid => "post:a.b.c", :document => {:text => "xyzzy"}, :created_by => 1, :restricted => true)
      Post.with_restrictions(identity).size.should eq 0
      post.visible_to?(identity).should eq false
    end

    it "succeed if identity has god status" do
      identity = DeepStruct.wrap({:id => 1337, :god => true})
      post = Post.create!(:uid => "post:a.b.c", :document => {:text => "xyzzy"}, :created_by => 1, :restricted => true)
      Post.with_restrictions(identity).size.should eq 1
      post.visible_to?(identity).should eq true
    end

    it "succeed if identity is the document creator" do
      identity = DeepStruct.wrap({:id => 1337, :god => false})
      post = Post.create!(:uid => "post:a.b.c", :document => {:text => "xyzzy"}, :created_by => 1337, :restricted => true)
      Post.with_restrictions(identity).size.should eq 1
      post.visible_to?(identity).should eq true
    end

    it "returns filters out inaccessible documents" do
      identity = DeepStruct.wrap({:id => 1337, :god => false})
      post = Post.create!(:uid => "post:a.b.c", :document => {:text => "xyzzy"}, :created_by => 1337, :restricted => true)
      another_post = Post.create!(:uid => "post:a.b.c", :document => {:text => "xyzzy"}, :created_by => 1, :restricted => true)
      posts = []
      [post, another_post].map{|p| p.visible_to?(identity)? posts << p : posts << nil }
      posts.count.should eq 2
      posts[0].should eq post
      posts[1].should eq nil
    end

  end

  context "Moderation of external documents" do
    it "returns the external_document attribute if the document attribute is not set" do
      post = Post.create!(:uid => "post:some.ext.thing", :external_document => {:title => "the quick brown fox"}, :created_by => 1337)
      post.merged_document[:title].should eq "the quick brown fox"
    end

    it "merges document into external_document with key/value pairs from document overriding external_document pairs" do
      post = Post.create!(:uid => "post:some.ext.thing", :external_document => {
        :brown => "fox",
        :lazy => "dog"
      }, :created_by => 1337)

      post.document = {:brown => "coyote"}

      post.merged_document.should eq(:brown => "coyote", :lazy => "dog")
    end

    it "keeps track of when the document was last updated" do
      post = Post.create!(:uid => "post:some.ext.thing", :document => {:title => "the quick brown fox"}, :created_by => 1337)
      post.document_updated_at.should_not be_nil
    end

    it "keeps track of when the external document was last updated" do
      post = Post.create!(:uid => "post:some.ext.thing", :external_document => {:title => "the quick brown fox"}, :created_by => 1337)
      post.external_document_updated_at.should_not be_nil
    end

    it "marks a post as conflicted if post has an external document newer than the document and document overrides any of its keys" do
      post = Post.create!(:uid => "post:a.b.c", :document => {:title => "the quick brown fox"}, :created_by => 1337)
      Timecop.freeze(Date.today + 1) do
        post.external_document = {:title => "jumps over the lazy dog"}
        post.external_document_updated_at.to_i.should be > post.document_updated_at.to_i
        post.save
        post.conflicted.should be_true
      end
    end

    it "doesn't mark a post as conflicted if there's no external document" do
      post = Post.create!(:uid => "post:a.b.c", :document => {:title => "the quick brown fox"}, :created_by => 1337)
      post.conflicted.should be_false
    end

    it "doesn't mark a post as conflicted if there's only an external document" do
      post = Post.create!(:uid => "post:a.b.c", :external_document => {:title => "the quick brown fox"}, :created_by => 1337)
      post.conflicted.should be_false
    end

    it "keeps only modified versions of keys in external_document" do
      post = Post.create!(:uid => "post:a.b.c", :external_document => {:quick => "fox", :lazy => "dog"}, :created_by => 1337)
      post.document = {:quick => "coyote", :lazy => "dog"}
      post.save
      post.document.should eq({:quick => "coyote"})
      post.merged_document.should eq({:quick => "coyote", :lazy => "dog"})
      post.external_document.should eq({:quick => "fox", :lazy => "dog"})
    end

    it "mark a post as conflicted only if keys in document are also in external_document" do
      post = Post.create!(:uid => "post:a.b.c", :document => {:brown => "fox"}, :created_by => 1337)
      Timecop.freeze(Date.today + 1) do
        post.external_document = {:lazy => "dog"}
        post.external_document_updated_at.to_i.should be > post.document_updated_at.to_i
        post.save
        post.conflicted.should be_false
      end
    end
  end

end
