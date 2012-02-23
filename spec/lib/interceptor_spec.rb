require 'interceptor'

describe Interceptor do

  let(:post) { stub(:realm => 'oz', :klass => 'post.event') }
  let(:options) { {:action => 'smile', :session => 'abc', :identity => stub(:id => 42)} }

  describe "basic attributes" do
    subject { Interceptor.new(post, options) }

    its(:post) { should eq(post) }
    its(:options) { should eq(options) }
    its(:action) { should eq('smile') }
    its(:tags) { should eq(['smile', 'event']) }
    its(:realm_and_tags) { should eq({'realm' => 'oz', 'tags' => ['smile', 'event']}) }

    it "ignores tags if they are empty" do
      subject.stub(:tags => [])
      subject.realm_and_tags.should eq({'realm' => 'oz'})
    end

    it "doesn't leave nils in tags" do
      subject.stub(:action => nil)
      subject.tags.should eq(['event'])
    end
  end

  describe "klass" do
    it "corresponds to the post's sub-klass" do
      Interceptor.new(stub(:klass => 'post.event')).klass.should eq('event')
    end

    it "is nil if the post is generic" do
      Interceptor.new(stub(:klass => 'post')).klass.should be_nil
    end
  end
end
