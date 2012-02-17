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

  describe "#process" do
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

    it "processes each interceptor" do
      Post.should_receive(:filtered_by).and_return [event_interceptor, blog_interceptor]
      event_interceptor.should_receive(:process).with(post)
      blog_interceptor.should_receive(:process).with(post)
      Interceptor.process(post)
    end
  end

end
