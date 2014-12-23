require 'spec_helper'

describe "API v1 changes" do

  include Rack::Test::Methods
  include Pebblebed::RSpecHelper

  def app
    GroveV1
  end

  before :each do
    app.set disable_callbacks: true
  end

  context 'when identity' do
    before :each do
      user!(:realm => 'a')
    end

    describe 'GET /changes/:uid' do
      it 'returns 404 if there is no path' do
        get '/changes/'
        expect(last_response.status).to eq 404
      end

      it 'returns changes for path' do
        post = Post.create!(
          uid: 'post:a.b.c',
          created_by: another_identity.id,
          document: {'text' => 'xyzzy'})

        get '/changes/post:a.b.c'
        expect(last_response.status).to eq 200

        changes = JSON.parse(last_response.body)['changes']
        expect(changes.length).to eq 1
        expect(changes[0]['id']).to_not be_nil
        expect(changes[0]['uid']).to eq post.uid
        expect(changes[0]['kind']).to eq 'create'
        expect(Time.parse(changes[0]['time']).beginning_of_minute).
          to eq post.created_at.beginning_of_minute
      end

      it 'supports wildcard path' do
        Post.create!(
          uid: 'post:a.b.c',
          created_by: another_identity.id,
          document: {'text' => 'xyzzy'})
        Post.create!(
          uid: 'post:x.y.z',
          created_by: another_identity.id,
          document: {'text' => 'xyzzy'})

        get '/changes/post:*'
        expect(last_response.status).to eq 200

        changes = JSON.parse(last_response.body)['changes']
        expect(changes.length).to eq 2
      end

      it 'supports specific UID' do
        post = Post.create!(
          uid: 'post:a.b.c',
          created_by: another_identity.id,
          document: {'text' => 'xyzzy'})

        get "/changes/#{post.uid}"
        expect(last_response.status).to eq 200

        changes = JSON.parse(last_response.body)['changes']
        expect(changes.length).to eq 1
        expect(changes[0]['uid']).to eq post.uid
      end

      it 'supports "limit" parameter' do
        Post.create!(
          uid: 'post:a.b.c',
          created_by: another_identity.id,
          document: {'text' => 'xyzzy1'})
        Post.create!(
          uid: 'post:a.b.c',
          created_by: another_identity.id,
          document: {'text' => 'xyzzy2'})

        get "/changes/post:a.b.c", limit: 1
        expect(last_response.status).to eq 200

        changes = JSON.parse(last_response.body)['changes']
        expect(changes.length).to eq 1
      end

      it 'supports "since" parameter' do
        post = Post.create!(
          uid: 'post:a.b.c',
          created_by: another_identity.id,
          document: {'text' => 'xyzzy1'})

        get "/changes/post:a.b.c", limit: 1
        expect(last_response.status).to eq 200

        last_change_id = JSON.parse(last_response.body)['changes'][0]['id']

        post.document = {}
        post.save!

        get "/changes/post:a.b.c", since: last_change_id
        expect(last_response.status).to eq 200

        changes = JSON.parse(last_response.body)['changes']
        expect(changes.length).to eq 1
        expect(changes[0]['uid']).to eq post.uid
        expect(changes[0]['kind']).to eq 'update'
      end
    end
  end

  context 'when no identity' do
    before :each do
      guest!
    end

    describe 'GET /changes/:path' do
      it 'returns 403' do
        get '/changes/post:a.b.c'
        expect(last_response.status).to eq 403
      end
    end
  end

end
