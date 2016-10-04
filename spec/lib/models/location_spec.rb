require 'spec_helper'

describe Location do

  it "is declare!d in an idempotent way" do
    Location.declare!('a.b.c')
    Location.declare!('a.b')
    Location.declare!('a')
    Location.declare!('c.b.c')
    Location.declare!('c.b.c')
    expect(Location.count).to eq 4
  end

  it "can be found by path" do
    Location.declare!('a.b.c')
    Location.declare!('a')
    target = Location.declare!('a.b')
    expect(Location.by_path('a.b').count).to eq 1
    expect(Location.by_path('a.b').first).to eq target
  end

  it "can be found by wildcard path" do
    Location.declare!('a.b.c')
    Location.declare!('a.b')
    Location.declare!('a')
    Location.declare!('c.b.c')

    expect(Location.by_path('a.*').count).to eq 3
    expect(Location.by_path('c.*').count).to eq 1
    expect(Location.by_path('*').count).to eq 4
    expect(Location.by_path('d.*').count).to eq 0
  end

  it "complains about invalid wildcard searches" do
    expect{ Location.by_path('*.c') }.to raise_error(ArgumentError)
  end

  it "can be found by set of paths" do
    Location.declare!('a.b')
    Location.declare!('a.b.a')
    Location.declare!('a.b.b')
    Location.declare!('a.b.c')
    Location.declare!('a.b.d')

    expect(Location.by_path('a.b.a|b|c').count).to eq 3
  end

  it "can match superpaths" do
    top = Location.declare!('a')
    Location.declare!('a.b')
    off_path = Location.declare!('a.c')
    Location.declare!('a.b.c')
    Location.declare!('a.b.c.d')
    bottom = Location.declare!('a.b.c.d.e')

    result = Location.by_path("^a.b.c").all
    expect(result.count).to eq 3
    expect(result).not_to include(off_path)

    result = Location.by_path("a.b.^c.d").all
    expect(result.count).to eq 3
    expect(result).not_to include(top)
    expect(result).not_to include(bottom)

  end

  it "won't accept malformed paths" do
    expect { Location.declare!("some.f@$%&ing.sh*t.characters")}.to raise_error ArgumentError
  end


  it "knows who has access" do
    group_id = 555
    identity_id = 1
    random_visitor_id = 2

    accessible_location = Location.declare!('rips.er.tvilsomt')
    GroupLocation.allow_subtree(group_id, 'rips.er.tvilsomt')
    expect(accessible_location.accessible_by?(identity_id)).to be_falsey

    GroupMembership.declare!(group_id, identity_id)
    expect(accessible_location.accessible_by?(identity_id)).to be_truthy

    inaccessible_location = Location.declare!('rips.suger')
    expect(inaccessible_location.accessible_by?(identity_id)).to be_falsey
    expect(inaccessible_location.accessible_by?(random_visitor_id)).to be_falsey
  end

 end
