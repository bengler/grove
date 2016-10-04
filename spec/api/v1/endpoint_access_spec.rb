# encoding: utf-8
require 'spec_helper'
require 'pebblebed/rspec_helper'

describe "API v1" do
  include Rack::Test::Methods
  include Pebblebed::RSpecHelper

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
    {:method => :put, :endpoint => '/posts/post:a.b.c$1/tags/:tags'},
    {:method => :get, :endpoint => '/readmarks/*'},
    {:method => :put, :endpoint => '/readmarks/a.b.c/post:a.b.c$10'}
  ]

  context "with no current user" do
    before(:each) { guest! }
    describe "has no access to user endpoints" do
      endpoints.each do |forbidden|
        it "fails to #{forbidden[:method]} #{forbidden[:endpoint]}" do
          self.send(forbidden[:method], forbidden[:endpoint])
          expect(last_response.status).to eq(403)
        end
      end
    end
  end
end
