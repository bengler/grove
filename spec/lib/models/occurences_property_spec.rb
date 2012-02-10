require 'spec_helper'

describe Post::OccurencesAccessor do
  it "persists occurences" do
    time = Time.now
    p = Post.create!(:uid => "post:a.b.c", :occurences => {:due => [time]})
    q = Post.find(p.id)
    q.occurences['due'].first.should be_within(1.0).of(time)
  end

  it "can be recovered from json without persisting" do
    p = Post.create!(:uid => "post:a.b.c", :occurences => {:due => [Time.now]})
    p.occurences['onlyjson'] = [Time.now]
    json = p.to_json
    q = Post.instantiate(JSON.parse(json)['post'])
    q.occurences['onlyjson'].size.should eq 1
    q.occurences['due'].size.should eq 1
    r = Post.find(p)
    r.occurences.keys.should eq ['due']
  end

  it "deletes occurences" do
    time = Time.now
    other_time = Time.now-1000
    p = Post.create!(:uid => "post:a.b.c", :occurences => {:due => [time, other_time]})
    q = Post.find(p)
    q.occurences['due'].size.should eq 2
    q.occurences['due'].pop
    q.save!
    r = Post.find(p)
    r.occurences['due'].size.should eq 1
    r.occurences = {}
    r.save!
    s = Post.find(p)
    s.occurences.keys.size.should eq 0
  end
end