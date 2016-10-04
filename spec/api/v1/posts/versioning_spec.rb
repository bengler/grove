# encoding: utf-8

require 'spec_helper'

describe 'Versioning' do

  include Rack::Test::Methods
  include Pebblebed::RSpecHelper

  def app
    GroveV1.set disable_callbacks: true
    GroveV1
  end

  before(:each) do
    god!(:realm => 'a')
  end

  it 'assigns a new version number to each modification' do
    post = Post.create!(uid: 'post:a.b.c',
      document: {text: 'I can spel'})
    post "/posts/#{post.uid}", post: {
      document: {content: 'I DO can spell'}}
    expect(last_response.status).to eq 200
    expect(JSON.parse(last_response.body)['post']['version']).to be > post.version
  end

  it 'does not allow version number on create' do
    post "/posts/post:a.b.c", post: {
      version: 420,
      document: {content: 'I DO can spell'}}
    expect(last_response.status).to eq 403
  end

  it 'returns 200 when attempting to update correct version' do
    post = Post.create!(uid: 'post:a.b.c',
      document: {text: 'I can spel'})
    expect(post.save).to be_truthy

    post "/posts/#{post.uid}", post: {
      version: post.version,
      document: {content: 'I DO can spell'}}
    expect(last_response.status).to eq 200
  end

  it 'returns 409 when attempting to update wrong version' do
    post = Post.create!(uid: 'post:a.b.c',
      document: {text: 'I can spel'})
    original_version = post.version
    expect(post.save).to be_truthy

    post "/posts/#{post.uid}", post: {
      version: original_version,
      document: {content: 'I DO can spell'}}
    expect(last_response.status).to eq 409
  end

end
