# encoding: utf-8
require 'spec_helper'

describe "Security callbacks" do
  include Rack::Test::Methods

  def app
    GroveV1.set :disable_callbacks => false
    GroveV1
  end

  let(:guest) { DeepStruct.wrap({}) }
  let(:alice) { DeepStruct.wrap(:identity => {:id => 1, :god => false, :realm => 'a'}) }
  let(:odin) { DeepStruct.wrap(:identity => {:id => 1337, :god => true, :realm => 'a'}) }

  let(:checkpoint) {
    # A richer mock-checkpoint that can handle different requests differently
    class Mockpoint
      def initialize(context)
        @context = context
      end
      def get(url, *args)
        case url
        when /^\/identities\/me/
          @context.identity
        end
      end
      def post(url, *args)
        case url
        when /^\/callbacks\/allowed/
          DeepStruct.wrap(@context.callback_response)
        end
      end

    end
    Mockpoint.new(self)
  }

  before :each do
    allow_any_instance_of(app).to receive(:current_session).and_return "validsessionyesyesyes"
    allow_any_instance_of(Pebblebed::Connector).to receive(:checkpoint).and_return checkpoint
  end

  context "when callbacks dictate action should be denied" do
    let(:identity) { alice }
    let(:callback_response) { {'allowed' => false, 'url' => "http://example.org", 'reason' => "You are not worthy"} }

    it "can't create a document" do
      post "/posts/post:a.b.c", :post => {:document => {content: "hello world"}}
      expect(Post.count).to eq 0
      expect(last_response.status).to eq 403
      expect(last_response.body).to eq "Not allowed to create post:a.b.c$. Reason: You are not worthy. Denied by: http://example.org"
    end
  end

  context "when callbacks dictate action should be allowed" do
    let(:identity) { alice }
    let(:callback_response) { {'allowed' => true} }

    it "can update another persons document" do
      p = Post.create!(:uid => "post:a.b.c", :created_by => 1337, :document => {'title' => 'Hello spaceboy'})
      post "/posts/#{p.uid}", :post => {:document => {:title => "Hello nobody"} }
      expect(last_response.status).to eq 200
      expect(p.reload.document['title']).to eq "Hello nobody"
    end
  end

  context "when callbacks dictate action should be allowed" do
    let(:identity) { alice }
    let(:callback_response) { {'allowed' => true} }

    it "can update another persons document" do
      p = Post.create!(:uid => "post:a.b.c", :created_by => 1337, :document => {'title' => 'Hello spaceboy'})
      post "/posts/#{p.uid}", :post => {:document => {:title => "Hello nobody"} }
      expect(last_response.status).to eq 200
      expect(p.reload.document['title']).to eq "Hello nobody"
    end
  end

  context "when callbacks dictate we use own judgement" do
    let(:identity) { alice }
    let(:callback_response) { {'allowed' => 'default'} }

    it "can update own document" do
      p = Post.create!(:uid => "post:a.b.c", :created_by => 1, :document => {'title' => 'Hello spaceboy'})
      post "/posts/#{p.uid}", :post => {:document => {:title => "Hello nobody"} }
      expect(last_response.status).to eq 200
      expect(p.reload.document['title']).to eq "Hello nobody"
    end

    it "can't update another persons document" do
      p = Post.create!(:uid => "post:a.b.c", :created_by => 1337, :document => {'title' => 'Hello spaceboy'})
      post "/posts/#{p.uid}", :post => {:document => {:title => "Hello nobody"} }
      expect(last_response.status).to eq 403
      expect(p.reload.document['title']).to eq "Hello spaceboy"
    end
  end

end
