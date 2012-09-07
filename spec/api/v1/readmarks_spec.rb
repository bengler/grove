require 'spec_helper'

describe "API v1 posts" do
  include Rack::Test::Methods

  def app
    GroveV1
  end

  before :each do
    Pebblebed::Connector.any_instance.stub(:checkpoint).and_return(stub(:get => the_identity))
  end

  context "with a logged in user" do
    let(:the_identity) { DeepStruct.wrap(:identity => {:id=>1337, :god => false}) }

    it "can set a readmark" do
      put "/readmarks/a.b.c/post:a.b.c$10"
      readmark = Readmark.first
      readmark.path.should eq "a.b.c"
      readmark.post_id.should eq 10
      readmark.owner.should eq 1337
      put "/readmarks/a.b.c/post:a.b.c$20"
      readmark.reload
      readmark.post_id.should eq 20
      Readmark.count.should eq 1
      json = JSON.parse(last_response.body)
      json['readmark']['oid'].should eq '20'
      json['readmark']['owner'].should eq 1337      
    end

    it "can get a specific readmark" do
      Readmark.set!(1337, "a.b.c", 10)
      Readmark.set!(1337, "a.b.d", 20)
      get "/readmarks/a.b.c"
      json = JSON.parse(last_response.body)
      json['readmark']['oid'].should eq '10'
    end

    it "can get a collection of readmarks" do
      Readmark.set!(1337, "a.b", 10)
      Readmark.set!(1337, "a.b.c", 10)
      Readmark.set!(1337, "a.d", 10)
      get "/readmarks/a.*"
      json = JSON.parse(last_response.body)
      json['readmarks'].size.should eq 3
      get "/readmarks/a.b.*"
      json = JSON.parse(last_response.body)
      json['readmarks'].size.should eq 2
    end

    it "will only get the readmarks of the current user" do
      Readmark.set!(1337, "a.b", 10)
      Readmark.set!(1338, "a.b.c", 10)
      Readmark.set!(1339, "a.d", 10)
      get "/readmarks/*"
      json = JSON.parse(last_response.body)
      json['readmarks'].size.should eq 1
      json['readmarks'].first['readmark']['owner'].should eq 1337
    end

  end


  context "with no current user" do
    let(:the_identity) { DeepStruct.wrap({}) }

    it "can't get or set readmarks" do
      get "/readmarks/*"
      last_response.status.should eq 403
      put "/readmarks/a.b.c/post:a.b.c$10"
      last_response.status.should eq 403
    end
  end

end
