# encoding: utf-8

require 'spec_helper'

describe 'Merging' do

  include Rack::Test::Methods
  include Pebblebed::RSpecHelper

  def app
    GroveV1.set disable_callbacks: true
    GroveV1
  end

  before(:each) do
    god!(:realm => 'a')
  end

  it 'ignores null changes' do
    post = Post.create!(uid: 'post:a.b.c',
      document: {text: 'ding dong'})
    post "/posts/#{post.uid}", merge: true, post: {
      document: {text: 'ding dong'}
    }
    expect(last_response.status).to eq 200
    expect(JSON.parse(last_response.body)['post']['version']).to eq post.version
  end

  it 'merges document' do
    post = Post.create!(uid: 'post:a.b.c',
      document: {text: 'ding'})
    post "/posts/#{post.uid}", merge: true, post: {
      document: {text2: 'dong'}
    }
    expect(last_response.status).to eq 200
    expect(JSON.parse(last_response.body)['post']['document']).to eq({
      'text' => 'ding',
      'text2' => 'dong'
    })
  end

  it 'merges recursively' do
    post = Post.create!(uid: 'post:a.b.c',
      document: {a: {b: 'ding', c: {d: 'd'}}})
    post "/posts/#{post.uid}", merge: true, post: {
      document: {a: {c: {d: 'd2'}, e: 'e'}}
    }
    expect(last_response.status).to eq 200
    expect(JSON.parse(last_response.body)['post']['document']).to eq({
      'a' => {
        'b' => 'ding',
        'c' => {
          'd' => 'd2',
        },
        'e' => 'e'
      }
    })
  end

  it 'retries merge on version conflict' do
    post = Post.create!(uid: 'post:a.b.c')
    old_version = post.version

    post.document = {text: 'ding'}
    post.save!

    post "/posts/#{post.uid}",
      merge: true,
      post: {
        version: old_version,
        document: {text2: 'dong'}
      }
    expect(last_response.status).to eq 200
    expect(JSON.parse(last_response.body)['post']['version']).to_not eq post.version
    expect(JSON.parse(last_response.body)['post']['document']).to eq({
      'text' => 'ding',
      'text2' => 'dong'
    })
  end

end
