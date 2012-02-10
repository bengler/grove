require 'spec_helper'

describe Post::OccurrencesAccessor do
  it "persists occurrences" do
    time = Time.now
    p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [time]})
    q = Post.find(p.id)
    q.occurrences['due'].first.should be_within(1.0).of(time)
  end

  it "can be recovered from json without persisting" do
    p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [Time.now]})
    p.occurrences['onlyjson'] = [Time.now]
    json = p.to_json
    q = Post.instantiate(JSON.parse(json)['post'])
    q.occurrences['onlyjson'].size.should eq 1
    q.occurrences['due'].size.should eq 1
    r = Post.find(p)
    r.occurrences.keys.should eq ['due']
  end

  it "deletes occurrences" do
    time = Time.now
    other_time = Time.now-1000
    p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [time, other_time]})
    q = Post.find(p)
    q.occurrences['due'].size.should eq 2
    q.occurrences['due'].pop
    q.save!
    r = Post.find(p)
    r.occurrences['due'].size.should eq 1
    r.occurrences = {}
    r.save!
    s = Post.find(p)
    s.occurrences.keys.size.should eq 0
  end
end