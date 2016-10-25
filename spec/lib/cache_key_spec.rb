require 'pebbles-uid'
require 'cache_key'

class Thing < Struct.new(:uid)
  include CacheKey
end

describe CacheKey do
  before(:each) do
    SchemaVersion.stub(:current => "--1")
  end

  it "converts UIDs to cache keys" do
    expect(CacheKey.from_uid('post.doc:a.b.c$42')).to eq('post.doc:a.*$42$%$schema:--1')
  end

  describe Thing do
    subject { Thing.new('post.card:one.two.three$13') }

    describe '#cache_key' do
      subject { super().cache_key }
      it { is_expected.to eq('post.card:one.*$13$%$schema:--1') }
    end
  end
end
