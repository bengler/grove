require 'spec_helper'

describe ChangeObserver do

  it 'generates "create" change record on create' do
    post = Post.create!(canonical_path: 'foo.bar')
    changes = Change.reorder('id')
    expect(changes.length).to eq 1
    expect(changes[0].kind).to eq 'create'
    expect(changes[0].post_id).to eq post.id
  end

  it 'generates "update" change record on update' do
    post = Post.create!(canonical_path: 'foo.bar')
    post.document = {a: 1}
    post.save!
    change = Change.reorder('id').last
    expect(change).to_not be_nil
    expect(change.kind).to eq 'update'
    expect(change.post_id).to eq post.id
  end

  it 'generates "delete" change record on delete' do
    post = Post.create!(canonical_path: 'foo.bar')
    post.delete!
    change = Change.reorder('id').last
    expect(change).to_not be_nil
    expect(change.kind).to eq 'delete'
    expect(change.post_id).to eq post.id
  end

  it 'generates "create" change record on undelete' do
    post = Post.create!(canonical_path: 'foo.bar')
    post.delete!
    post.deleted = false
    post.save!
    change = Change.reorder('id').last
    expect(change).to_not be_nil
    expect(change.kind).to eq 'create'
    expect(change.post_id).to eq post.id
  end

end
