require 'spec_helper'

describe Post::LocationsAccessor do 
  it "will only persist when record is saved" do
    p = Post.create!(:uid => 'post:a.b.c')
    p.paths = ['a.not.persisted']
    q = Post.find(p.id)
    q.paths.to_a.should eq ["a.b.c"]
  end

  it "can put a post in a path persist it" do
    p = Post.create!(:uid => 'post:a.b.c')
    p.paths.to_a.should eq ['a.b.c']
    p.paths << 'a.ping.pong'
    p.save!
    q = Post.find(p.id)
    p.paths.to_a.should include "a.ping.pong"
  end

  it "can be instantiatet from json without persisting the paths as a side effect" do
    p = Post.create!(:uid => 'post:a.b.c')
    p.paths = ['only.in.json']
    # Convert to json, but don't save
    json = p.to_json
    # Save with different paths
    p.paths = ['anton.kaanan', 'ranveig.banan'] 
    p.save!
    # Double check that the new set was persisted
    z = Post.find(p.id)
    z.paths.to_a.sort.should eq ['a.b.c', 'anton.kaanan', 'ranveig.banan'].sort
    # Reheat model from json with stale path data
    puts json
    p JSON.parse(json)['post']
    q = Post.instantiate(JSON.parse(json)['post'])
    # Check that we got the old path in the stale model
    q.paths.to_a.should eq ['only.in.json']
    # Check that reloading or loading the model from scratch will not include the stale path
    r = Post.find(p.id)    
    r.paths.to_a.sort.should_not include 'only.in.json'
    q.reload
    q.paths.to_a.sort.should_not include 'only.in.json'
  end
end