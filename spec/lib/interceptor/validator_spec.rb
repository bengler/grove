require 'ostruct'
require 'interceptor/validator'

class Callback; end
class Post; end

describe Interceptor::Validator do
  describe "wraps post" do
    let(:attributes) {
      {
        :created_by => 1,
        :realm => 'realm',
        :uid => 'uid',
        :tags => %w(a b c),
        :document => {
          :url => 'url'
        }
      }
    }
    let(:post) { OpenStruct.new(attributes) }

    let(:validator) { Interceptor::Validator.new(post) }
    subject { validator }

    its(:url) { should eq('url') }
    its(:realm) { should eq('realm') }
    its(:uid) { should eq('uid') }

    describe "additional attributes" do
      subject do
        validator.with(:action => 'singing', :session => 'abc')
      end

      its(:action) { should eq('singing') }
      its(:session) { should eq('abc') }
    end
  end

end
