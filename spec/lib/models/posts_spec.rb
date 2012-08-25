require 'spec_helper'

describe Post do

  context "from uid" do
    let(:card) { Post.create!(:uid => "post.card:area51.ufo.pix") }
    subject { card }

    its(:realm) { should eq('area51') }
    its(:canonical_path) { should eq('area51.ufo.pix') }
    its(:klass) { should eq('post.card') }
  end

  let(:default_attributes) do
    {
      :klass => 'post.doc',
      :canonical_path => "area51.secret.research",
      :document => {'text' => '1'}
    }
  end

  let(:article) { Post.create!(default_attributes) }

  subject { article }

  its(:realm) { should eq('area51') }
  its(:uid) { should eq("post.doc:area51.secret.research$#{article.id}") }

  context "locations" do

    it "defaults to the canonical location" do
      subject.locations.map { |loc| loc.path.to_s }.should eq(["area51.secret.research"])
    end

    it "cannot delete the canonical path" do
      Location.declare!("area51.xyz").posts << article
      ->{ article.remove_path!('area51.secret.research') }.should raise_error ArgumentError
      article.reload
      article.paths.to_a.sort.should eq(['area51.secret.research', 'area51.xyz'])
    end

    specify "are like symlinks" do
      symlink = "area51.classified.research"
      Location.declare!(symlink).posts << article

      Post.find_by_uid("post.doc:#{symlink}$#{article.id}").should eq(article)
    end

    specify "are not returned in duplicate" do
      symlink = "area51.classified.research"
      Location.declare!(symlink).posts << article

      Post.by_uid("post.doc:*").should eq([article])
    end
  end

  it 'atomically adds a path' do
    article.should_not_receive(:save)
    article.should_not_receive(:save!)

    article.add_path!("area51.xyz")

    article.reload
    article.paths.to_a.sort.should eq(['area51.secret.research', 'area51.xyz'])
  end

  it 'atomically deletes a path' do
    other_article = Post.create!(:uid => "post:area51.abc", :document => {"text" => "2"})
    Location.declare!("area51.xyz").posts << article
    Location.declare!("area51.xyz").posts << other_article

    article.should_not_receive(:save)
    article.should_not_receive(:save!)

    article.remove_path!("area51.xyz")

    article.reload
    other_article.reload

    article.paths.to_a.should eq(["area51.secret.research"])
    other_article.paths.to_a.sort.should eq(["area51.abc", "area51.xyz"])
  end

  describe "finders and filters" do

    it "finds by uid" do
      Post.find_by_uid(article.uid).document['text'].should eq('1')
    end

    it "returns nil for non-existant posts" do
      Post.find_by_uid("post:area51.secret.work$2").should be_nil
    end

    it "filters by realm" do
      # Does not match
      Post.create!(:uid => "post:oz.other.place")

      Post.filtered_by('realm' => article.realm).should eq([article])
    end

    context "filters tags" do
      before(:each) do
        Post.create!(:uid => "post.card:x.y.z", :tags => ["paris", "france"], :document => {'text' => '1'})
        Post.create!(:uid => "post.card:x.y.z", :tags => ["paris", "texas"], :document => {'text' => '2'})
        Post.create!(:uid => "post.card:x.y.z", :tags => ["lyon", "france"], :document => {'text' => '3'})
      end

      specify "exclusively" do
        Post.with_tags("paris").all.map {|p| p.document['text']}.sort.should eq ['1', '2']
      end

      it "with an exclusive AND" do
        Post.with_tags(["paris", "france"]).all.map{|p| p.document['text']}.sort.should eq ['1']
      end
    end

    describe "wildcard matches" do
      before(:each) do
        Post.create!(:uid => "post:area51.secret.research", :document => {:text => "1"})
        Post.create!(:uid => "post:area51.secret.research", :document => {:text => "2"})
        Post.create!(:uid => "post:area51.secret.experiments", :document => {:text => "3"})
        Post.create!(:uid => "post:area52.secret.experiments", :document => {:text => "4"})
      end

      specify "finds on klass" do
        Post.by_uid("post:*").map(&:document).map{|document| document[:text]}.sort.should eq ['1', '2', '3', '4']
      end

      specify "finds on partial path" do
        Post.by_uid("post:area51.*").map(&:document).map{|document| document[:text]}.sort.should eq ['1', '2', '3']
      end

      specify "finds on fully specified path" do
        Post.by_uid("post:area51.secret.research").map(&:document).map{|document| document[:text]}.sort.should eq ['1', '2']
      end
    end

    specify "returns an empty set for wildcard uids with no matches" do
      Post.by_uid("post:route66.*").should eq([])
    end

    describe "readthrough cache" do
      let(:memo) { Post.create!(:uid => "post.doc:area51.secret.research", :document => {:text => "2"}) }

      it "gets primed on fetch" do
        Post.cached_find_all_by_uid([article.uid])

        post = JSON.parse($memcached.get(article.cache_key))
        post['document']['text'].should eq '1'
      end

      it "reads from the cache" do
        article.document = 'sentinel'
        $memcached.set(article.cache_key, article.attributes.to_json)

        posts = Post.cached_find_all_by_uid([article.uid])
        posts.first.document.should eq 'sentinel'
      end

      it "respects order in the request" do
        $memcached.set(article.cache_key, article.attributes.to_json)

        posts = Post.cached_find_all_by_uid([memo.uid, article.uid])
        posts.map {|p| p.document['text'] }.should eq(['2', '1'])
      end

      it "performs with partial hits" do
        $memcached.set(memo.cache_key, memo.attributes.to_json)

        posts = Post.cached_find_all_by_uid([article.uid, memo.uid])
        posts.map {|p| p.document['text']}.should eq(['1', '2'])
      end

      it "invalidates the cache" do
        $memcached.set(article.cache_key, article.attributes.to_json)
        article.document = "watchdog"
        article.save!
        posts = Post.cached_find_all_by_uid([article.uid])
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

      it "bails on caret" do
        ->{ Post.cached_find_all_by_uid(["post:with.caret.^a.b.c"]) }.should raise_error ArgumentError
      end
    end
  end

  context "restricted documents" do

    let(:nobody) { DeepStruct.wrap({}) }
    let(:john_q_public) { DeepStruct.wrap({:id => 101, :god => false}) }
    let(:alice) { DeepStruct.wrap({:id => 42, :god => false}) }
    let(:zeus) { DeepStruct.wrap({:id => 1337, :god => true}) }

    before(:each) do
      default_attributes.merge!(:restricted => true, :created_by => 42)
    end

    specify "are inaccessible without an identity" do
      article.visible_to?(nobody).should eq false
      Post.with_restrictions(nobody).size.should eq 0
    end

    specify "are inaccessible to random people" do
      article.visible_to?(john_q_public).should eq false
      Post.with_restrictions(john_q_public).size.should eq 0
    end

    specify "are accessible to document creator" do
      article.visible_to?(alice).should eq true
      Post.with_restrictions(alice).size.should eq 1
    end

    specify "are accessible to god" do
      article.visible_to?(zeus).should eq true
      Post.with_restrictions(zeus).size.should eq 1
    end
  end

  describe "conflicts" do

    # The document store in post consists of
    # :external_document
    # :document
    # :merged_document (read-only)
    #
    # The external document is only relevant if the post is
    # imported from or synced with an external source.
    #
    # The document will in this case be used to override the
    # values of selected keys.
    #
    # The merged document is the combination of the two.

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
      article.conflicted?.should == false
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
