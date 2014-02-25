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

  context "validations" do

    it "validates format of external_id" do
      lambda {
        Post.create!(default_attributes.merge(:external_id => "123:werwer"))
      }.should raise_error ActiveRecord::RecordInvalid, "Validation failed: External must start with a non-digit character"
      lambda {
        Post.create!(default_attributes.merge(:external_id => "a_123:werwer"))
      }.should_not raise_error
    end
  end

  context "locations" do

    it "defaults to the canonical location" do
      subject.locations.map { |loc| loc.path.to_s }.should eq(["area51.secret.research"])
    end

    it "cannot delete the canonical path" do
      pending "must be implemented in the locations accessor" do
        Location.declare!("area51.xyz").posts << article
        ->{ article.remove_path!('area51.secret.research') }.should raise_error ArgumentError
        article.reload
        article.paths.to_a.sort.should eq(['area51.secret.research', 'area51.xyz'])
      end
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
    article.add_path!("area51.xyz")

    article.reload
    article.paths.to_a.sort.should eq(['area51.secret.research', 'area51.xyz'])
  end

  it 'atomically deletes a path' do
    other_article = Post.create!(:uid => "post:area51.abc", :document => {"text" => "2"})
    Location.declare!("area51.xyz").posts << article
    Location.declare!("area51.xyz").posts << other_article

    # Manipulating the locations outside of the posts api requires reload
    article.reload

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

    describe "wildcard path matches" do
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

    describe "wildcard klass matches" do
      before(:each) do
        Post.create!(:uid => "post:a.b", :document => {:text => "1"})
        Post.create!(:uid => "post.card:a.b", :document => {:text => "2"})
        Post.create!(:uid => "post.box:a.b", :document => {:text => "3"})
        Post.create!(:uid => "post.man:a.b", :document => {:text => "4"})
      end

      specify "any klass" do
        Post.by_uid("*:*").map(&:document).map{|document| document[:text]}.sort.should eq ['1', '2', '3', '4']
      end

      specify "this or that" do
        Post.by_uid("post.card|post.man:a.*").map(&:document).map{|document| document[:text]}.sort.should eq ['2', '4']
        Post.by_uid("post.card|box:a.*").map(&:document).map{|document| document[:text]}.sort.should eq ['2']
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
        article.document = {'key' => 'sentinel'}
        $memcached.set(article.cache_key, article.attributes.to_json)

        posts = Post.cached_find_all_by_uid([Pebbles::Uid.cache_key(article.uid)])
        posts.first.document.should eq({'key' => 'sentinel'})
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
        article.document = {'text' => "watchdog"}
        article.save!
        posts = Post.cached_find_all_by_uid([article.uid])
        posts.first.document.should eq('text' => 'watchdog')
      end

      it "returns nil placeholders for non-existant posts" do
        posts = Post.cached_find_all_by_uid(["post:out.of.this$1"])
        posts.should eq [nil]
      end

      it "returns list of posts by oids" do
        posts = Post.cached_find_all_by_uid(["post.doc:area51.*$#{memo.id}","post.doc:area51.*$23344234234"])
        posts.length.should eq 2
        posts.first.should eq memo
        posts.last.should eq nil
      end
    end
  end

  context "access control" do

    let(:nobody) { DeepStruct.wrap({}) }
    let(:john_q_public) { DeepStruct.wrap({:id => 1, :god => false, :realm => 'area51'}) }
    let(:alice) { DeepStruct.wrap({:id => 2, :god => false, :realm => 'area51'}) }
    let(:zeus) { DeepStruct.wrap({:id => 1337, :god => true, :realm => 'area51'}) }
    let(:false_god) { DeepStruct.wrap({:id => 1337, :god => true, :realm => 'area52'}) }

    context "public documents" do
      before(:each) do
        default_attributes.merge!(:restricted => false, :created_by => 2)
      end

      specify "are visible" do
        article.visible_to?(nobody).should eq true
        Post.with_restrictions(nobody).size.should eq 1
      end

      specify "cannot be edited without an identity" do
        article.editable_by?(nobody).should eq false
      end

      specify "cannot be edited by just anyone" do
        article.editable_by?(john_q_public).should eq false
      end

      specify "can be edited by the owner" do
        article.editable_by?(alice).should eq true
      end

      specify "can be edited by god" do
        article.editable_by?(zeus).should eq true
      end
    end

    context "restricted documents" do

      before(:each) do
        default_attributes.merge!(:restricted => true, :created_by => 2)
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

      specify "are accessible to god in same realm" do
        article.visible_to?(zeus).should eq true
        Post.with_restrictions(zeus).count.should eq 1
      end

      specify "are inaccessible to god in wrong realm" do
        article.visible_to?(false_god).should eq false
        Post.with_restrictions(false_god).count.should eq 0
      end
    end

    context "published status" do

      it "makes published posts accessible to random people" do
        default_attributes.merge!(:published => true, :created_by => 2)
        article.visible_to?(john_q_public).should eq true
        Post.with_restrictions(john_q_public).size.should eq 1
      end

      it "makes unpublished stuff inaccessible to random people" do
        default_attributes.merge!(:published => false, :created_by => 2)
        article.visible_to?(john_q_public).should eq false
        Post.with_restrictions(john_q_public).size.should eq 0
      end
    end
  end

  describe 'external documents' do

    let :truth do
      {'observed' => 'explosion', 'cause' => 'alien aircraft crash'}
    end

    let :lies do
      {'casualties' => 'none'}
    end

    let :press_release_attributes do
      default_attributes.merge(document: {}, external_document: truth)
    end

    let :press_release do
      Post.create!(press_release_attributes)
    end

    describe "conflicts" do
      context "without external document" do
        it "isn't conflicted" do
          article.conflicted?.should eq false
        end
      end

      context "with only an external document" do
        it "isn't conflicted" do
          doc = Post.create!(default_attributes.merge(
            document: nil,
            external_document: {text: '1'}))
          doc.conflicted?.should eq false
        end
      end
    end

    describe 'timestamps' do
      it "updating document with no changes does not affect timestamp" do
        previous_update = press_release.document_updated_at
        previous_sync = press_release.external_document_updated_at

        press_release.document = {}
        press_release.save!

        press_release.document_updated_at.should eq previous_update
        press_release.external_document_updated_at.should eq previous_sync
      end

      it "updating external document with no changes does not affect timestamp" do
        previous_update = press_release.document_updated_at
        previous_sync = press_release.external_document_updated_at

        press_release.external_document = press_release.external_document.dup
        press_release.save!

        press_release.document_updated_at.should eq previous_update
        press_release.external_document_updated_at.should eq previous_sync
      end

      it "updating document changes its timestamp, but not external document's timestamp" do
        previous_update = press_release.document_updated_at
        previous_sync = press_release.external_document_updated_at

        press_release.document = {cause: 'weather balloon'}
        press_release.save!

        press_release.document_updated_at.should > previous_update
        press_release.external_document_updated_at.should == previous_sync
      end

      it "updating external document changes its timestamp, but document's timestamp" do
        previous_update = press_release.document_updated_at
        previous_sync = press_release.external_document_updated_at

        press_release.external_document = {casualties: 4}
        press_release.save!

        press_release.document_updated_at.should == previous_update
        press_release.external_document_updated_at.should > previous_sync
      end
    end

    describe "merged value" do
      it "defaults to the external document's value" do
        press_release.merged_document['cause'].should eq 'alien aircraft crash'
      end

      it "gets overridden by values in document" do
        post = Post.create!(press_release_attributes)
        post.document = {cause: 'mining accident'}
        post.merged_document['cause'].should eq 'mining accident'
      end

      it 'preserves untouched document keys' do
        post = Post.create!(press_release_attributes.merge(document: {cause: 'mining accident'}))
        post.merged_document['observed'].should eq 'explosion'
      end

      it 'preserves document keys that are the same as external document' do
        press_release.document = press_release.external_document
        press_release.document.empty?.should eq true
      end
    end

    context "with a newer sync than document" do
      it "is conflicted with overridden keys" do
        post = Post.create!(press_release_attributes.merge(document: {cause: 'mining accident'}))
        post.external_document = {cause: 'alien aircraft crash'}
        post.save
        post.conflicted?.should eq true
      end

      it "is not conflicted without overridden keys" do
        press_release.external_document = truth.merge(casualties: 4)
        press_release.save
        press_release.conflicted?.should eq false
      end
    end

    context "when document is newer than sync" do
      it "is not conflicted" do
        post = Post.create!(press_release_attributes)
        post.document = {casualties: 0}
        post.conflicted?.should eq false
      end
    end
  end

  describe "delete" do

    context "when a post is deleted" do
      it "will free up its external_id" do
        post = Post.create!(default_attributes.merge(:external_id => "s1"))
        post.deleted = true
        post.save!
        post.external_id.should be_nil
      end

      it "will archive its external_id" do
        external_id = "s1"
        post = Post.create!(default_attributes.merge(:external_id => external_id))
        post.deleted = true
        post.save!
        post.document['external_id'].should eq external_id
      end
    end

    context "when a post is undeleted" do
      it "will not be reassigned the old external_id" do
        post = Post.create!(default_attributes.merge(:external_id => "s1"))
        post.deleted = true
        post.save!
        post.deleted = false
        post.save!
        post.external_id.should be_nil
      end
    end
  end

end
