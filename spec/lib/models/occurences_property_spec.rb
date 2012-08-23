require 'spec_helper'

describe Post::OccurrencesAccessor do
  before(:each) do
    Timecop.freeze(Time.utc(2012, 2, 7, 18, 28, 18))
  end

  after(:each) do
    Timecop.return
  end

  let(:time) { Time.now }

  it "persists occurrences" do
    p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [time]})
    q = Post.find(p.id)
    q.occurrences['due'].first.should eq(time)
  end

  it "ignores occurrences if there are none" do
    p = Post.create!(:uid => "post:a.b.c")
    q = Post.find(p.id)
    q.merged_document.should eq(nil)
  end

  it "puts occurrences into the merged document" do
    p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [time]})
    q = Post.find(p.id)
    q.merged_document.should eq({"occurrences" => {"due" => [time]}})

  end

  it "can be recovered from json without persisting" do
    p = Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [time]})
    p.occurrences['onlyjson'] = [time]
    json = p.to_json
    q = Post.instantiate(JSON.parse(json)['post'])
    q.occurrences['onlyjson'].size.should eq 1
    q.occurrences['due'].size.should eq 1
    r = Post.find(p)
    r.occurrences.keys.should eq ['due']
  end

  it "deletes occurrences" do
    other_time = time - 1000
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

  it "can select posts with a specific occurrence type" do
    Post.create!(:uid => "post:a.b.c", :occurrences => {:odd => [time]})
    Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [time]})
    Post.by_occurrence('due').count.should eq 1
    Post.by_occurrence('strange').count.should eq 0
  end

  it "can limit occurrence selection by time range" do
    Post.create!(:uid => "post:a.b.c", :occurrences => {:due => [time]})
    Post.by_occurrence('due').occurs_before(time-1).count.should eq 0
    Post.by_occurrence('due').occurs_before(time+1).count.should eq 1
    Post.by_occurrence('due').occurs_after(time-1).count.should eq 1
    Post.by_occurrence('due').occurs_after(time+1).count.should eq 0
  end
end
