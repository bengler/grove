require 'ostruct'
require 'models/watchdog'

class Post; end

describe Watchdog do
  describe "wraps Post" do
    let(:attributes) {
      {
        :created_by => 1,
        :realm => 'realm',
        :uid => 'uid',
        :tags => %w(p r q),
        :document => {
          :paths => 'x,y,z',
          :klasses => 'a,b,c',
          :url => 'url'
        }
      }
    }
    let(:post) { OpenStruct.new(attributes) }

    subject { Watchdog.new(post) }

    its(:klasses) { should eq(%w(a b c)) }
    its(:actions) { should eq(%w(p r q)) }
    its(:paths) { should eq(%w(x y z)) }
    its(:url) { should eq('url') }
    its(:realm) { should eq('realm') }
    its(:uid) { should eq('uid') }
  end
end
