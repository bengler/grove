require 'models/location/wildcard_path'

describe WildcardPath do

  describe "is or is not" do
    it { WildcardPath.is_it?('*').should be_true }
    it { WildcardPath.is_it?('a.b|c.d').should be_true }
    it { WildcardPath.is_it?('a.^b.d').should be_true }
    it { WildcardPath.is_it?('a.b.d').should be_false }
  end

  describe "valid paths" do
    specify { WildcardPath.valid?('*').should be_true }
    specify { WildcardPath.valid?('a.b.c.*').should be_true }
    specify { WildcardPath.valid?('a.b|c.d').should be_true }
    specify { WildcardPath.valid?('a.b|c.*').should be_true }
    specify { WildcardPath.valid?('^a').should be_true }
    specify { WildcardPath.valid?('^a.b').should be_true }
    specify { WildcardPath.valid?('^a.b.c').should be_true }
    specify { WildcardPath.valid?('a.^b.c').should be_true }
    specify { WildcardPath.valid?('a.^b.c|d.e').should be_true }
    specify { WildcardPath.valid?('a.^b.c.*').should be_true }
  end

  describe "invalid paths" do
    specify { WildcardPath.valid?('*a').should be_false }
    specify { WildcardPath.valid?('a*').should be_false }
    specify { WildcardPath.valid?('*.b').should be_false }
    specify { WildcardPath.valid?('a.*.b').should be_false }
    specify { WildcardPath.valid?('|').should be_false }
    specify { WildcardPath.valid?('a.|b').should be_false }
    specify { WildcardPath.valid?('a.b|').should be_false }
    specify { WildcardPath.valid?('a.|b.c').should be_false }
    specify { WildcardPath.valid?('a.b|.c').should be_false }
    specify { WildcardPath.valid?('^').should be_false }
    specify { WildcardPath.valid?('^.a').should be_false }
    specify { WildcardPath.valid?('a^').should be_false }
    specify { WildcardPath.valid?('a^b.c').should be_false }
  end

end
