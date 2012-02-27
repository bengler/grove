require 'spec_helper'

describe Location do
  it "is declare!d in an idempotent way" do
    Location.declare!('a.b.c')
    Location.declare!('a.b')
    Location.declare!('a')
    Location.declare!('c.b.c')
    Location.declare!('c.b.c')
    Location.count.should eq 4
  end

  it "can be found by path" do
    Location.declare!('a.b.c')
    Location.declare!('a')
    target = Location.declare!('a.b')
    Location.by_path('a.b').count.should eq 1
    Location.by_path('a.b').first.should eq target
  end

  it "can be found by wildcard path" do
    Location.declare!('a.b.c')
    Location.declare!('a.b')
    Location.declare!('a')
    Location.declare!('c.b.c')

    Location.by_path('a.*').count.should eq 3
    Location.by_path('c.*').count.should eq 1
    Location.by_path('*').count.should eq 4
    Location.by_path('d.*').count.should eq 0
  end

  it "doesn't bother checking all remaining labels for nil" do
    Location.parse_path('a.b').should eq({:label_0=>"a", :label_1=>"b", :label_2=>nil})
  end

  it "can be found by set of paths" do
    Location.declare!('a.b')
    Location.declare!('a.b.a')
    Location.declare!('a.b.b')
    Location.declare!('a.b.c')
    Location.declare!('a.b.d')

    Location.by_path('a.b.a|b|c').count.should eq 3
  end

  it "can match superpaths" do
    top = Location.declare!('a')
    Location.declare!('a.b')
    off_path = Location.declare!('a.c')
    Location.declare!('a.b.c')
    Location.declare!('a.b.c.d')
    bottom = Location.declare!('a.b.c.d.e')

    result = Location.by_path("^a.b.c").all
    result.count.should eq 3
    result.should_not include(off_path)

    result = Location.by_path("a.b.^c.d").all
    result.count.should eq 3
    result.should_not include(top)
    result.should_not include(bottom)

  end

  it "can't contain stray nils" do
    -> { Location.create!(:label_1 => "something")}.should raise_error ActiveRecord::RecordInvalid
  end

  it "won't accept malformed paths" do
    -> { Location.declare!("some.f@$%&ing.sh*t.characters")}.should raise_error ActiveRecord::RecordInvalid
  end
 end
