source 'http://rubygems.org'

gem 'sinatra'
gem 'sinatra-activerecord'
gem 'activerecord', :require => 'active_record'
gem 'pg'
gem 'yajl-ruby', :require => "yajl"
gem 'rabl'
gem 'pebbles', :git => 'git@github.com:origo/pebblebed.git'
gem 'dalli'
gem 'ts_vector_tags'

group :development, :test do
  gem 'rspec', '~> 2.7.0.rc1'
  # a monkeypatch in rack 1.3.4 causes :WFKV_ to be declared twice
  # so to silence the warning, adding this line until we upgrade to
  # rack v. 1.3.5
  gem 'rack-test'
  gem 'simplecov'
  gem 'capistrano', '=2.5.19'
  gem 'capistrano-ext', '=1.2.1'
  gem 'timecop'
  gem 'vcr'
  gem 'webmock'
end
