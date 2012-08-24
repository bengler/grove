require 'spec_helper'

describe Post do

  context "from uid" do
    let(:card) { Post.create!(:uid => "post.card:area51.vaktmesterkontoret.forum1") }
    subject { card }

    its(:realm) { should eq('area51') }
    its(:canonical_path) { should eq('area51.vaktmesterkontoret.forum1') }
    its(:klass) { should eq('post.card') }
  end

  let(:default_attributes) do
    {
      :klass => 'post.doc',
      :canonical_path => "area51.vaktmesterkontoret.forum1",
      :document => {'text' => '1'}
    }
  end

  let(:post) { Post.create!(default_attributes) }

  subject { post }

  its(:realm) { should eq('area51') }
  its(:uid) { should eq("post.doc:area51.vaktmesterkontoret.forum1$#{post.id}") }

  context "locations" do

    it "defaults to the canonical location" do
      subject.locations.map { |loc| loc.path.to_s }.should eq(["area51.vaktmesterkontoret.forum1"])
    end

    it "cannot delete the canonical path" do
      Location.declare!("x.y.z").posts << post
      ->{ post.remove_path!('area51.vaktmesterkontoret.forum1') }.should raise_error ArgumentError
      post.reload
      post.paths.to_a.sort.should eq(['area51.vaktmesterkontoret.forum1', 'x.y.z'])
    end

    specify "are like symlinks" do
      symlink = "area51.vikarkontoret.forum1"
      Location.declare!(symlink).posts << post

      Post.find_by_uid("post.doc:#{symlink}$#{post.id}").should eq(post)
    end

    specify "are not returned in duplicate" do
      symlink = "area51.vikarkontoret.forum1"
      Location.declare!(symlink).posts << post

      Post.by_uid("post.doc:*").should eq([post])
    end
  end

  it 'atomically adds a path' do
    post.should_not_receive(:save)
    post.should_not_receive(:save!)

    post.add_path!("x.y.z")

    post.reload
    post.paths.to_a.sort.should eq(['area51.vaktmesterkontoret.forum1', 'x.y.z'])
  end

  it 'atomically deletes a path' do
    other_post = Post.create!(:uid => "post:a.b.c.d.e", :document => {"text" => "2"})
    Location.declare!("x.y.z").posts << post
    Location.declare!("x.y.z").posts << other_post

    post.should_not_receive(:save)
    post.should_not_receive(:save!)

    post.remove_path!("x.y.z")

    post.reload
    other_post.reload

    post.paths.to_a.should eq(["area51.vaktmesterkontoret.forum1"])
    other_post.paths.to_a.sort.should eq(["a.b.c.d.e", "x.y.z"])
  end

  describe "finders and filters" do

    it "finds by uid" do
      Post.find_by_uid(post.uid).document['text'].should eq('1')
    end

    it "returns nil for non-existant posts" do
      Post.find_by_uid("post:area51.vaktmesterkontoret.forumX$2").should be_nil
    end

    it "filters by realm" do
      Post.create!(:uid => "post:oz.other.place")

      posts = Post.filtered_by('realm' => post.realm)
      posts.size.should eq(1)
      posts.first.uid.should eq(post.uid)
    end

    context "filters tags" do
      before(:each) do
        Post.create!(:uid => "post:x.y.z", :tags => ["france", "paris"], :document => {'text' => '1'})
        Post.create!(:uid => "post:x.y.z", :tags => ["capitals", "paris"], :document => {'text' => '2'})
        Post.create!(:uid => "post:x.y.z", :tags => ["france", "lyon"], :document => {'text' => '3'})
      end

      it "finds only posts matching tag" do
        Post.with_tags("paris").all.map {|p| p.document['text']}.sort.should eq ['1', '2']
      end

      it "finds only posts matching ALL tags" do
        Post.with_tags(["france", "paris"]).all.map{|p| p.document['text']}.sort.should eq ['1']
      end
    end

    describe "wildcard uids" do
      before(:each) do
        Post.create!(:uid => "post:area51.vaktemsterkontoret.forum1", :document => {:text => "1"})
        Post.create!(:uid => "post:area51.vaktemsterkontoret.forum1", :document => {:text => "2"})
        Post.create!(:uid => "post:area51.vaktemsterkontoret.forum2", :document => {:text => "3"})
        Post.create!(:uid => "post:area52.vaktemsterkontoret.forum2", :document => {:text => "4"})
      end

      it "finds on wildcard with klass" do
        Post.by_uid("post:*").map(&:document).map{|document| document[:text]}.sort.should eq ['1', '2', '3', '4']
      end

      it "finds on wildcard with partial path" do
        Post.by_uid("post:area51.*").map(&:document).map{|document| document[:text]}.sort.should eq ['1', '2', '3']
      end

      it "finds on wildcard with fully specified path" do
        Post.by_uid("post:area51.vaktemsterkontoret.forum1").map(&:document).map{|document| document[:text]}.sort.should eq ['1', '2']
      end
    end

    it "returns an empty set if there are no matches" do
      Post.by_uid("post:highway61.*").should eq([])
    end

    describe "readthrough cache" do
      let(:doc1) { post }
      let(:doc2) { Post.create!(:uid => "post.doc:area51.vaktemsterkontoret.forum1", :document => {:text => "2"}) }

      it "gets primed on fetch" do
        Post.cached_find_all_by_uid([doc1.uid])

        post = JSON.parse($memcached.get(doc1.cache_key))
        post['document']['text'].should eq '1'
      end

      it "reads from the cache" do
        doc1.document = 'sentinel'
        $memcached.set(doc1.cache_key, doc1.attributes.to_json)

        posts = Post.cached_find_all_by_uid([doc1.uid])
        posts.first.document.should eq 'sentinel'
      end

      it "respects order in the request" do
        $memcached.set(doc1.cache_key, doc1.attributes.to_json)

        posts = Post.cached_find_all_by_uid([doc2.uid, doc1.uid])
        posts.map {|post| post.document['text'] }.should eq(['2', '1'])
      end

      it "performs with partial hits" do
        $memcached.set(doc2.cache_key, doc2.attributes.to_json)

        posts = Post.cached_find_all_by_uid([doc1.uid, doc2.uid])
        posts.map{|p| p.document['text']}.should eq(['1', '2'])
      end

      it "invalidates the cache" do
        $memcached.set(doc1.cache_key, doc1.attributes.to_json)
        doc1.document = "watchdog"
        doc1.save!
        posts = Post.cached_find_all_by_uid([doc1.uid])
        posts.first.document.should eq 'watchdog'
      end

      it "returns nil placeholders for non-existant posts" do
        posts = Post.cached_find_all_by_uid(["post:out.of.this$1"])
        posts.should eq [nil]
      end

      it "bails on wildcards" do
        ->{ Post.cached_find_all_by_uid(["post:with.wildcard.*"]) }.should raise_error ArgumentError
      end

      it "bails on pipes" do
        ->{ Post.cached_find_all_by_uid(["post:with.pipes.a|b|c"]) }.should raise_error ArgumentError
      end
    end
  end

  context "restricted documents" do

    before(:each) do
      default_attributes.merge!(:restricted => true, :created_by => 42)
    end

    let(:nobody) { DeepStruct.wrap({}) }
    let(:john_q_public) { DeepStruct.wrap({:id => 101, :god => false}) }
    let(:alice) { DeepStruct.wrap({:id => 42, :god => false}) }
    let(:zeus) { DeepStruct.wrap({:id => 1337, :god => true}) }

    specify "are inaccessible without an identity" do
      post.visible_to?(nobody).should eq false
      Post.with_restrictions(nobody).size.should eq 0
    end

    specify "are inaccessible to random people" do
      post.visible_to?(john_q_public).should eq false
      Post.with_restrictions(john_q_public).size.should eq 0
    end

    specify "are accessible to document creator" do
      post.visible_to?(alice).should eq true
      Post.with_restrictions(alice).size.should eq 1
    end

    specify "are accessible to god" do
      post.visible_to?(zeus).should eq true
      Post.with_restrictions(zeus).size.should eq 1
    end
  end

  describe "conflicts" do

    let(:external_document) do
      {'title' => 'Greeting', 'text' => 'Hello, World!'}
    end

    let(:document) do
      {}
    end

    let(:external_attributes) do
      default_attributes.merge(:document => document, :external_document => external_document)
    end

    let(:external_post) { Post.create!(external_attributes) }

    it "isn't conflicted without an external document" do
      post.conflicted?.should == false
    end

    it "isn't conflicted without a document" do
      doc = Post.create!(default_attributes.merge(:document => nil, :external_document => external_document))
      doc.conflicted?.should == false
    end

    it "tracks updated at for document" do
      previous_update = external_post.document_updated_at
      previous_sync = external_post.external_document_updated_at
      external_post.document = external_post.document.merge!('ps' => 'Call me!')
      external_post.save!
      external_post.document_updated_at.should > previous_update
      external_post.external_document_updated_at.should == previous_sync
    end

    it "tracks updated at for external document" do
      previous_update = external_post.document_updated_at
      previous_sync = external_post.external_document_updated_at
      external_post.external_document = external_post.external_document.merge!('ps' => 'Call me!')
      external_post.save!
      external_post.document_updated_at.should == previous_update
      external_post.external_document_updated_at.should > previous_sync
    end

    context "when merged" do
      it "defaults to the external document" do
        external_post.merged_document['text'].should eq "Hello, World!"
      end

      it "gets overridden by values in document" do
        document.merge!('text' => 'Hiya, Cowboys!')
        external_post.merged_document['text'].should eq 'Hiya, Cowboys!'
      end
    end

    context "with a newer sync than document" do
      it "is conflicted with overridden keys" do
        document.merge!('text' => 'Hey, there.')
        external_post.external_document = external_post.external_document.merge!('ps' => 'Call me!')
        external_post.save
        external_post.conflicted?.should == true
      end

      it "is not conflicted without overridden keys" do
        document.merge!('who' => 'Everybody!')
        external_post.external_document = external_post.external_document.merge!('ps' => 'Call me!')
        external_post.save
        external_post.conflicted?.should == false
      end
    end

    context "when document is newer than sync" do
      before(:each) do
        document.merge!('text' => 'Hey, there.')
        external_post.document = external_post.document.merge!('ps' => 'Call me!')
        external_post.save!
      end

      it "is not conflicted" do
        external_post.conflicted?.should == false
      end
    end
  end

  # TODO: This should be configurable
  it "sanitizes some fields if the content is json" do
    Post.create!(:uid => "post:x.y.z", :tags => ["france", "paris"], :document => {"text" => "<a><script>hei"})
    Post.first.document['text'].should eq "hei"
  end

end
