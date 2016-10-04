require 'spec_helper'
require 'pebblebed/rspec_helper'

describe "API v1 posts" do
  include Rack::Test::Methods
  include Pebblebed::RSpecHelper

  def app
    GroveV1
  end

  context "with a logged in user" do
    before(:each) { user! }

    it "can set a readmark" do
      put "/readmarks/a.b.c/post:a.b.c$10"
      readmark = Readmark.first
      expect(readmark.path).to eq "a.b.c"
      expect(readmark.post_id).to eq 10
      expect(readmark.owner).to eq 1
      put "/readmarks/a.b.c/post:a.b.c$20"
      readmark.reload
      expect(readmark.post_id).to eq 20
      expect(Readmark.count).to eq 1
      json = JSON.parse(last_response.body)
      expect(json['readmark']['oid']).to eq '20'
      expect(json['readmark']['owner']).to eq 1
    end

    it "can get a specific readmark" do
      Readmark.set!(1, "a.b.c", 10)
      Readmark.set!(1, "a.b.d", 20)
      get "/readmarks/a.b.c"
      json = JSON.parse(last_response.body)
      expect(json['readmark']['oid']).to eq '10'
    end

    it "can get a collection of readmarks" do
      Readmark.set!(1, "a.b", 10)
      Readmark.set!(1, "a.b.c", 10)
      Readmark.set!(1, "a.d", 10)
      get "/readmarks/a.*"
      json = JSON.parse(last_response.body)
      expect(json['readmarks'].size).to eq 3
      get "/readmarks/a.b.*"
      json = JSON.parse(last_response.body)
      expect(json['readmarks'].size).to eq 2
    end

    it "will only get the readmarks of the current user" do
      Readmark.set!(1, "a.b", 10)
      Readmark.set!(2, "a.b.c", 10)
      Readmark.set!(3, "a.d", 10)
      get "/readmarks/*"
      json = JSON.parse(last_response.body)
      expect(json['readmarks'].size).to eq 1
      expect(json['readmarks'].first['readmark']['owner']).to eq 1
    end

  end

end
