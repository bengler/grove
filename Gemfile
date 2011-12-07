source 'http://rubygems.org'

gem 'sinatra'
gem 'sinatra-contrib'
gem 'sinatra-activerecord'
gem 'rack-contrib', :git => 'git@github.com:rack/rack-contrib.git'
gem 'activerecord', :require => 'active_record'
gem 'pg'
gem 'yajl-ruby', :require => "yajl"
gem 'rabl'
gem 'pebblebed', :git => 'git@github.com:benglerpebbles/pebblebed.git'
gem 'dalli'
gem 'ts_vector_tags'
gem 'rake'
gem 'unicorn', '~> 4.1.1'

group :development, :test do
  gem 'bengler_test_helper',  :git => "git@github.com:origo/bengler_test_helper.git"
  gem 'rspec', '~> 2.7.0.rc1'
  # a monkeypatch in rack 1.3.4 causes :WFKV_ to be declared twice
  # so to silence the warning, adding this line until we upgrade to
  # rack v. 1.3.5
  gem 'rack-test'
  gem 'simplecov'
  gem 'capistrano', '=2.0.8'
  gem 'capistrano-ext', '=1.2.1'
  gem 'timecop'
  gem 'vcr'
  gem 'webmock'
end
