require 'spec_helper'

describe Post::GeoAccessor do
  it "accesse the lon/lat variables via the geo accessors" do
    p = Post.new(:uid => "post:test")
    p.geo.lon = 10.0
    p.geo.lat = 12.5
    p.save!

    p = Post.find(p.id)

    p.geo.lon.should eq 10.0
    p.geo.lat.should eq 12.5
  end

  it "marshals the lon/lat into a separate compound field in the json-hash" do
    p = Post.new(:uid => "post:test")
    p.geo.lon = 10.0
    p.geo.lat = 12.5

    json = JSON.parse(p.to_json)['post']

    json['lon'].should be_nil
    json['geo']['lon'].should eq 10.0
  end

  it "wraps the attributes in a compound field in the attributes_for_export hash" do
    p = Post.new(:uid => "post:test")
    p.geo.lon = 10.0
    p.geo.lat = 12.5
    attrs = p.attributes_for_export
    attrs['geo']['lon'].should eq 10.0
    attrs['lon'].should be_nil
  end
end
