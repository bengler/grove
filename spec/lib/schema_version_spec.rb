require 'spec_helper'

describe SchemaVersion do
  it "knows how to tag and untag a key" do
    SchemaVersion.tag_key("key").should =~ /^key\$\%\$schema\:.+$/
    SchemaVersion.untag_key("key$%$schema:123").should eq "key"
  end
end

