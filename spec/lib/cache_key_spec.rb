require 'pebblebed'
require 'cache_key'

class Thing < Struct.new(:uid)
  include CacheKey
end

describe CacheKey do
  before(:each) do
    SchemaVersion.stub(:current => "--1")
  end

  it "converts UIDs to cache keys" do
    CacheKey.from_uid('post.doc:a.b.c$42').should eq('post.doc:*$42$%$schema:--1')
  end

  describe Thing do
    subject { Thing.new('post.card:one.two.three$13') }

    its(:cache_key) { should eq('post.card:*$13$%$schema:--1') }
  end
end
