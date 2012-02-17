require 'ostruct'
require 'models/interceptor'

class Post; end

describe Interceptor do
  describe "wraps Post" do
    let(:attributes) {
      {
        :created_by => 1,
        :realm => 'realm',
        :uid => 'uid',
        :tags => %w(a b c),
        :document => {
          :paths => 'x,y,z',
          :url => 'url'
        }
      }
    }
    let(:post) { OpenStruct.new(attributes) }

    subject { Interceptor.new(post) }

    its(:klasses_and_actions) { should eq(%w(a b c)) }
    its(:paths) { should eq(%w(x y z)) }
    its(:url) { should eq('url') }
    its(:realm) { should eq('realm') }
    its(:uid) { should eq('uid') }
  end
end
