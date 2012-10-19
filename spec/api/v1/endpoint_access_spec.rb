# encoding: utf-8
require 'spec_helper'

describe "API v1" do
  include Rack::Test::Methods

  def app
    GroveV1
  end

  endpoints = [
    {:method => :post, :endpoint => '/posts/post:a.b.c'},
    {:method => :post, :endpoint => '/posts/post:a.b.c$1/paths/a.b.d'},
    {:method => :delete, :endpoint => '/posts/post:a.b.c$1/paths/a.b.d'},
    {:method => :post, :endpoint => '/posts/post:a.b.c$1/occurrences/due'},
    {:method => :delete, :endpoint => '/posts/post:a.b.c$1/occurrences/due'},
    {:method => :put, :endpoint => '/posts/post:a.b.c$1/occurrences/due'},
    {:method => :put, :endpoint => '/posts/post:a.b.c$1/touch'},
    {:method => :put, :endpoint => '/posts/post:a.b.c$1/tags/:tags'}
  ]

  let(:guest) { DeepStruct.wrap({}) }

  let(:checkpoint) { stub(:get => guest) }

  before :each do
    Pebblebed::Connector.any_instance.stub(:checkpoint).and_return checkpoint
  end

  context "with no current user" do
    describe "has no access to user endpoints" do
      endpoints.each do |forbidden|
        it "fails to #{forbidden[:method]} #{forbidden[:endpoint]}" do
          self.send(forbidden[:method], forbidden[:endpoint])
          last_response.status.should eq(403)
        end
      end
    end
  end
end
