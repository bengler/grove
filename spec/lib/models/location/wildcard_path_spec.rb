require 'models/location/wildcard_path'

describe WildcardPath do

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
  end

end
