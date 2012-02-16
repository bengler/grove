require 'deepstruct'
require 'models/app_validation'

class Post; end

describe AppValidation do

  it "has a default uid" do
    AppValidation.new(:realm => 'oz').uid.should eq('post.app_validation:oz')
  end

  describe "sanized lists" do
    let(:attributes) {
      {:klasses => '  a, b   ,c   ', :actions => ' p , r,   q ', :paths => 'x,y,z'}
    }
    subject { AppValidation.new(attributes) }

    its(:klasses) { should eq(%w(a b c)) }
    its(:actions) { should eq(%w(p r q)) }
    its(:paths) { should eq(%w(x y z)) }
  end

  describe "wraps Post" do
    let(:attributes) {
      {:url => 'url', :realm => 'realm', :uid => 'uid', :klasses => 'a,b,c', :actions => 'p,r,q', :paths => 'x,y,z', :created_by => 1}
    }

    let(:post_ready_hash) {
      {
        :created_by => 1,
        :realm => 'realm',
        :uid => 'uid',
        :tags => 'p,r,q',
        :document => {
          :paths => 'x,y,z',
          :klasses => 'a,b,c',
          :url => 'url'
        }
      }
    }

    describe "app validation -> post" do
      it "creates a post-ready hash" do
        AppValidation.new(attributes).as_json.should eq(post_ready_hash)
      end
    end

    describe "post -> app validation" do
      let(:post) { stub(:post, :attributes => post_ready_hash) }
      subject { AppValidation.from_post(post) }

      its(:as_json) { should eq(post_ready_hash) }
      its(:post) { should eq(post) }
    end
  end
end
