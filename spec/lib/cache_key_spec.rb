require 'pebblebed'
require 'cache_key'

describe CacheKey do
  it "converts UIDs to cache keys" do
    CacheKey.from_uid('post.doc:a.b.c$42').should eq('post.doc:*$42')
  end
end


class Thing < Struct.new(:uid)
  include CacheKey

end

describe Thing do
  subject { Thing.new('post.card:one.two.three$13') }

  its(:cache_key) { should eq('post.card:*$13') }
end
