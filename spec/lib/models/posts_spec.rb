require 'spec_helper'

describe Post do

  context "from uid" do
    let(:card) { Post.create!(:uid => "post.card:area51.ufo.pix") }
    subject { card }

    describe '#realm' do
      subject { super().realm }
      it { is_expected.to eq('area51') }
    end

    describe '#canonical_path' do
      subject { super().canonical_path }
      it { is_expected.to eq('area51.ufo.pix') }
    end

    describe '#klass' do
      subject { super().klass }
      it { is_expected.to eq('post.card') }
    end
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

  describe '#realm' do
    subject { super().realm }
    it { is_expected.to eq('area51') }
  end

  describe '#uid' do
    subject { super().uid }
    it { is_expected.to eq("post.doc:area51.secret.research$#{article.id}") }
  end

  context "validations" do

    it "validates format of external_id" do
      expect {
        Post.create!(default_attributes.merge(:external_id => "123:werwer"))
      }.to raise_error ActiveRecord::RecordInvalid, "Validation failed: External must start with a non-digit character"
      expect {
        Post.create!(default_attributes.merge(:external_id => "a_123:werwer"))
      }.not_to raise_error
    end
  end

  context "locations" do

    it "defaults to the canonical location" do
      expect(subject.locations.map { |loc| loc.path.to_s }).to eq(["area51.secret.research"])
    end

    it "cannot delete the canonical path" do
      skip "must be implemented in the locations accessor"
      Location.declare!("area51.xyz").posts << article
      expect{ article.remove_path!('area51.secret.research') }.to raise_error ArgumentError
      article.reload
      article.paths.to_a.sort.should eq(['area51.secret.research', 'area51.xyz'])
    end

    specify "are like symlinks" do
      symlink = "area51.classified.research"
      Location.declare!(symlink).posts << article

      expect(Post.find_by_uid("post.doc:#{symlink}$#{article.id}")).to eq(article)
    end

    specify "are not returned in duplicate" do
      symlink = "area51.classified.research"
      Location.declare!(symlink).posts << article

      expect(Post.by_uid("post.doc:*")).to eq([article])
    end
  end

  it 'atomically adds a path' do
    article.add_path!("area51.xyz")

    article.reload
    expect(article.paths.to_a.sort).to eq(['area51.secret.research', 'area51.xyz'])
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

    expect(article.paths.to_a).to eq(["area51.secret.research"])
    expect(other_article.paths.to_a.sort).to eq(["area51.abc", "area51.xyz"])
  end

  describe '#filtered_by' do
    let! :article1 do
      p = Post.create!(default_attributes)
      p.created_at = p.updated_at = Time.parse("1950-01-01 12:00:00")
      p.record_timestamps = false
      p.save!
      p
    end

    let! :article2 do
      p = Post.create!(default_attributes)
      p.created_at = p.updated_at = Time.parse("1951-01-01 12:00:01")
      p.record_timestamps = false
      p.save!
      p
    end

    describe 'document normalization' do
      it 'keeps nil values as nil values' do
        p = Post.create!(default_attributes.merge({:document => {:foo => {:bar => nil}}}))
        p.save!
        expect(p.document).to eq ({"foo" => {"bar" => nil}})
      end
    end

    describe '"since" parameter' do
      it 'returns posts created at or after timestamp' do
        expect(Post.filtered_by(
          'since' => Time.parse('1951-01-01 12:00:00')
        ).order('id')).to eq [article2]

        expect(Post.filtered_by(
          'since' => Time.parse('1950-01-01 12:00:00')
        ).order('id')).to eq [article1, article2]

        expect(Post.filtered_by(
          'since' => Time.parse('1951-01-01 12:00:01')
        ).order('id')).to eq [article2]

        expect(Post.filtered_by(
          'since' => Time.parse('1951-01-01 12:00:02')
        )).to eq []

        expect(Post.filtered_by('since' => Time.now + 10.years)).to be_empty
      end

      it 'truncates timestamp to nearest second' do
        expect(Post.filtered_by(
          'since' => Time.parse('1951-01-01 12:00:01.500')
        ).order('id')).to eq [article2]
      end

      it 'accepts string timestamp' do
        expect(Post.filtered_by(
          'since' => '1951-01-01 12:00:00'
        ).order('id')).to eq [article2]
      end
    end
  end

  describe "finders and filters" do

    it "finds by uid" do
      expect(Post.find_by_uid(article.uid).document['text']).to eq('1')
    end

    it "returns nil for non-existant posts" do
      expect(Post.find_by_uid("post:area51.secret.work$2")).to be_nil
    end

    it "filters by realm" do
      # Does not match
      Post.create!(:uid => "post:oz.other.place")

      expect(Post.filtered_by('realm' => article.realm)).to eq([article])
    end

    context "filters tags" do
      before(:each) do
        Post.create!(:uid => "post.card:x.y.z", :tags => ["paris", "france"], :document => {'text' => '1'})
        Post.create!(:uid => "post.card:x.y.z", :tags => ["paris", "texas"], :document => {'text' => '2'})
        Post.create!(:uid => "post.card:x.y.z", :tags => ["lyon", "france"], :document => {'text' => '3'})
      end

      specify "exclusively" do
        expect(Post.with_tags("paris").all.map {|p| p.document['text']}.sort).to eq ['1', '2']
      end

      it "with an exclusive AND" do
        expect(Post.with_tags(["paris", "france"]).all.map{|p| p.document['text']}.sort).to eq ['1']
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
        expect(Post.by_uid("post:*").map(&:document).map{|document| document[:text]}.sort).to eq ['1', '2', '3', '4']
      end

      specify "finds on partial path" do
        expect(Post.by_uid("post:area51.*").map(&:document).map{|document| document[:text]}.sort).to eq ['1', '2', '3']
      end

      specify "finds on fully specified path" do
        expect(Post.by_uid("post:area51.secret.research").map(&:document).map{|document| document[:text]}.sort).to eq ['1', '2']
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
        expect(Post.by_uid("*:*").map(&:document).map{|document| document[:text]}.sort).to eq ['1', '2', '3', '4']
      end

      specify "this or that" do
        expect(Post.by_uid("post.card|post.man:a.*").map(&:document).map{|document| document[:text]}.sort).to eq ['2', '4']
        expect(Post.by_uid("post.card|box:a.*").map(&:document).map{|document| document[:text]}.sort).to eq ['2']
      end
    end

    specify "returns an empty set for wildcard uids with no matches" do
      expect(Post.by_uid("post:route66.*")).to eq([])
    end

    describe "readthrough cache" do
      let(:memo) { Post.create!(:uid => "post.doc:area51.secret.research", :document => {:text => "2"}) }

      it "gets primed on fetch" do
        Post.cached_find_all_by_uid([article.uid])

        post = JSON.parse($memcached.get(article.cache_key))
        expect(post['document']['text']).to eq '1'
      end

      it "reads from the cache" do
        article.document = {'key' => 'sentinel'}
        $memcached.set(article.cache_key, article.attributes.to_json)

        posts = Post.cached_find_all_by_uid([Pebbles::Uid.cache_key(article.uid)])
        expect(posts.first.document).to eq({'key' => 'sentinel'})
      end

      it "respects order in the request" do
        $memcached.set(article.cache_key, article.attributes.to_json)

        posts = Post.cached_find_all_by_uid([memo.uid, article.uid])
        expect(posts.map {|p| p.document['text'] }).to eq(['2', '1'])
      end

      it "performs with partial hits" do
        $memcached.set(memo.cache_key, memo.attributes.to_json)

        posts = Post.cached_find_all_by_uid([article.uid, memo.uid])
        expect(posts.map {|p| p.document['text']}).to eq(['1', '2'])
      end

      it "invalidates the cache" do
        $memcached.set(article.cache_key, article.attributes.to_json)
        article.document = {'text' => "watchdog"}
        article.save!
        posts = Post.cached_find_all_by_uid([article.uid])
        expect(posts.first.document).to eq('text' => 'watchdog')
      end

      it "returns nil placeholders for non-existant posts" do
        posts = Post.cached_find_all_by_uid(["post:out.of.this$1"])
        expect(posts).to eq [nil]
      end

      it "returns list of posts by oids" do
        posts = Post.cached_find_all_by_uid(["post.doc:area51.*$#{memo.id}","post.doc:area51.*$23344234234"])
        expect(posts.length).to eq 2
        expect(posts.first).to eq memo
        expect(posts.last).to eq nil
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
        expect(article.visible_to?(nobody)).to eq true
        expect(Post.with_restrictions(nobody).size).to eq 1
      end

      specify "cannot be edited without an identity" do
        expect(article.editable_by?(nobody)).to eq false
      end

      specify "cannot be edited by just anyone" do
        expect(article.editable_by?(john_q_public)).to eq false
      end

      specify "can be edited by the owner" do
        expect(article.editable_by?(alice)).to eq true
      end

      specify "can be edited by god" do
        expect(article.editable_by?(zeus)).to eq true
      end
    end

    context "restricted documents" do

      before(:each) do
        default_attributes.merge!(:restricted => true, :created_by => 2)
      end

      specify "are inaccessible without an identity" do
        expect(article.visible_to?(nobody)).to eq false
        expect(Post.with_restrictions(nobody).size).to eq 0
      end

      specify "are inaccessible to random people" do
        expect(article.visible_to?(john_q_public)).to eq false
        expect(Post.with_restrictions(john_q_public).size).to eq 0
      end

      specify "are accessible to document creator" do
        expect(article.visible_to?(alice)).to eq true
        expect(Post.with_restrictions(alice).size).to eq 1
      end

      specify "are accessible to god in same realm" do
        expect(article.visible_to?(zeus)).to eq true
        expect(Post.with_restrictions(zeus).count).to eq 1
      end

      specify "are inaccessible to god in wrong realm" do
        expect(article.visible_to?(false_god)).to eq false
        expect(Post.with_restrictions(false_god).count).to eq 0
      end
    end

    context "published status" do

      it "makes published posts accessible to random people" do
        default_attributes.merge!(:published => true, :created_by => 2)
        expect(article.visible_to?(john_q_public)).to eq true
        expect(Post.with_restrictions(john_q_public).size).to eq 1
      end

      it "makes unpublished stuff inaccessible to random people" do
        default_attributes.merge!(:published => false, :created_by => 2)
        expect(article.visible_to?(john_q_public)).to eq false
        expect(Post.with_restrictions(john_q_public).size).to eq 0
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
          expect(article.conflicted?).to eq false
        end
      end

      context "with only an external document" do
        it "isn't conflicted" do
          doc = Post.create!(default_attributes.merge(
            document: nil,
            external_document: {text: '1'}))
          expect(doc.conflicted?).to eq false
        end
      end
    end

    describe 'timestamps' do
      it "updating document with no changes does not affect timestamp" do
        previous_update = press_release.document_updated_at
        previous_sync = press_release.external_document_updated_at

        press_release.document = {}
        press_release.save!

        expect(press_release.document_updated_at).to eq previous_update
        expect(press_release.external_document_updated_at).to eq previous_sync
      end

      it "updating external document with no changes does not affect timestamp" do
        previous_update = press_release.document_updated_at
        previous_sync = press_release.external_document_updated_at

        press_release.external_document = press_release.external_document.dup
        press_release.save!

        expect(press_release.document_updated_at).to eq previous_update
        expect(press_release.external_document_updated_at).to eq previous_sync
      end

      it "updating document changes its timestamp, but not external document's timestamp" do
        previous_update = press_release.document_updated_at
        previous_sync = press_release.external_document_updated_at

        press_release.document = {cause: 'weather balloon'}
        press_release.save!

        expect(press_release.document_updated_at).to be > previous_update
        expect(press_release.external_document_updated_at).to eq(previous_sync)
      end

      it "updating external document changes its timestamp, but document's timestamp" do
        previous_update = press_release.document_updated_at
        previous_sync = press_release.external_document_updated_at

        press_release.external_document = {casualties: 4}
        press_release.save!

        expect(press_release.document_updated_at).to eq(previous_update)
        expect(press_release.external_document_updated_at).to be > previous_sync
      end
    end

    describe "merged value" do
      it "defaults to the external document's value" do
        expect(press_release.merged_document['cause']).to eq 'alien aircraft crash'
      end

      it "gets overridden by values in document" do
        post = Post.create!(press_release_attributes)
        post.document = {cause: 'mining accident'}
        expect(post.merged_document['cause']).to eq 'mining accident'
      end

      it 'preserves untouched document keys' do
        post = Post.create!(press_release_attributes.merge(document: {cause: 'mining accident'}))
        expect(post.merged_document['observed']).to eq 'explosion'
      end

      it 'preserves document keys that are the same as external document' do
        press_release.document = press_release.external_document
        expect(press_release.document.empty?).to eq true
      end
    end

    context "with a newer sync than document" do
      it "is conflicted with overridden keys" do
        post = Post.create!(press_release_attributes.merge(document: {cause: 'mining accident'}))
        post.external_document = {cause: 'alien aircraft crash'}
        post.save
        expect(post.conflicted?).to eq true
      end

      it "is not conflicted without overridden keys" do
        press_release.external_document = truth.merge(casualties: 4)
        press_release.save
        expect(press_release.conflicted?).to eq false
      end
    end

    context "when document is newer than sync" do
      it "is not conflicted" do
        post = Post.create!(press_release_attributes)
        post.document = {casualties: 0}
        expect(post.conflicted?).to eq false
      end
    end
  end

  describe "delete" do

    context "when a post is deleted" do
      it "will free up its external_id" do
        post = Post.create!(default_attributes.merge(:external_id => "s1"))
        post.deleted = true
        post.save!
        expect(post.external_id).to be_nil
      end

      it "will archive its external_id" do
        external_id = "s1"
        post = Post.create!(default_attributes.merge(:external_id => external_id))
        post.deleted = true
        post.save!
        expect(post.document['external_id']).to eq external_id
      end
    end

    context "when a post is undeleted" do
      it "will not be reassigned the old external_id" do
        post = Post.create!(default_attributes.merge(:external_id => "s1"))
        post.deleted = true
        post.save!
        post.deleted = false
        post.save!
        expect(post.external_id).to be_nil
      end
    end
  end

  describe 'versioning' do
    it 'assigns version initially' do
      post = Post.create!(uid: 'post:a.b.c', document: {text: 'foo'})
      expect(post.version).not_to be_nil
    end

    it 'increments version on update' do
      post = Post.create!(uid: 'post:a.b.c', document: {text: 'foo'})
      version = post.version
      post.document = {text: 'bar'}
      post.save!
      expect(post.version).to be > version
    end
  end

end
