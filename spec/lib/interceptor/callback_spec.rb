require 'spec_helper'
require 'approvals_helper'
require 'timecop'

describe Interceptor::Callback do

  before(:each) do
    Timecop.travel(Time.utc(2011, 2, 7, 18, 28, 18))
  end

  after(:each) do
    Timecop.return
  end

  let(:validator) {
    p = Post.create!(:uid => 'post.validator:a', :created_by => 1, :tags => ['salutation', 'update'], :realm => 'a', :document => {:url => 'http://grove.dev/api/grove/v1/test/callback'})
    Interceptor::Validator.new(p).with(:action => :update, :session => 'abc', :identity => stub(:id => 1))
  }

  let(:post) {
    Post.create!(:uid => "post.salutation:a.b.c", :created_by => 1, :document => {:title => 'Hello spaceboy'}, :realm => 'a')
  }

  context "request body" do
    let(:callback) { Interceptor::Callback.new(validator, post) }

    it "contains the original and the changes" do
      post.stub(:id => 42)
      post.document = {:title => 'Hello cowboy'}

      Approvals.verify(callback.request_body, :format => :json, :name => 'interceptor template')
    end
  end

  describe "executing the callback" do
    let(:post) { OpenStruct.new(:document => {"hello" => "spaceboy"}) }
    let(:callback) { Interceptor::Callback.new(validator, post) }

    context "without changes" do
      it "returns the unchanged post" do
        callback.stub(:perform_request).and_return [200, {"status" => "pass", "changes" => {}}.to_json]
        callback.execute.document["hello"].should eq("spaceboy")
      end
    end

    context "with changes" do
      it "updates the post" do
        callback.stub(:perform_request).and_return [200, {"status" => "revised", "changes" => {:document => {"hello" => "cowgirl"}}}.to_json]
        callback.execute.document["hello"].should eq("cowgirl")
      end
    end

    context "with errors" do
      it "raises an unauthorized error" do
        callback.stub(:perform_request).and_return [403, 'No can do']
        ->{ callback.execute }.should raise_error UnauthorizedChangeError
      end

      it "raises some other error" do
        callback.stub(:perform_request).and_return [500, 'Eeew']
        ->{ callback.execute }.should raise_error StandardError
      end
    end

  end
end
