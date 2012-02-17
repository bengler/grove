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

    let(:interceptor) { Interceptor.new(post) }
    subject { interceptor }

    its(:klasses_and_actions) { should eq(%w(a b c)) }
    its(:paths) { should eq(%w(x y z)) }
    its(:url) { should eq('url') }
    its(:realm) { should eq('realm') }
    its(:uid) { should eq('uid') }

    describe "additional attributes" do
      subject do
        interceptor.with(:action => 'singing', :session => 'abc', :identity => stub(:id => 42))
      end

      its(:action) { should eq('singing') }
      its(:session) { should eq('abc') }
      its(:identity_id) { should eq(42) }
    end
  end

  describe "Interceptor#process" do
    let(:post) { stub(:realm => 'oz', :klass => 'post.event') }
    let(:event_interceptor) { stub(:klasses => ['concert', 'event', 'show']) }
    let(:blog_interceptor) { stub(:klasses => ['blog', 'comment', 'conversation']) }

    it "finds the correct validators" do
      Post.should_receive(:filtered_by).with(:realm => 'oz', :tags => ['singing', 'event']).and_return []
      Interceptor.process(post, :action => 'singing')
    end

    it "doesn't pass sub-klasses where it's irrelevant" do
      post.stub(:klass => 'post')

      Post.should_receive(:filtered_by).with(:realm => 'oz', :tags => ['singing']).and_return []
      Interceptor.process(post, :action => 'singing')
    end
  end
end
