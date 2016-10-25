require 'spec_helper'

describe SchemaVersion do
  it "knows how to tag and untag a key" do
    expect(SchemaVersion.tag_key("key")).to match(/^key\$\%\$schema\:.+$/)
    expect(SchemaVersion.untag_key("key$%$schema:123")).to eq "key"
  end
end

