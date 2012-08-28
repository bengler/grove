source 'http://rubygems.org'

gem 'sinatra'
gem 'sinatra-contrib'
gem 'sinatra-activerecord'
gem 'rack-contrib', :git => 'git://github.com/rack/rack-contrib.git'
gem 'activerecord', :require => 'active_record'
gem 'pg'
gem 'yajl-ruby', :require => "yajl"
gem 'petroglyph'
gem 'pebblebed'
gem 'pebbles-cors', :git => 'git@github.com:bengler/pebbles-cors.git'
gem 'dalli'
gem 'ts_vector_tags'
gem 'rake'
gem 'unicorn', '~> 4.1.1'
gem 'bengler_test_helper',  :git => "git://github.com/bengler/bengler_test_helper.git"
gem 'sanitize'
gem 'curb'
gem 'pebble_path'

group :development, :test do
  gem 'rspec', '~> 2.8'
  # a monkeypatch in rack 1.3.4 causes :WFKV_ to be declared twice
  # so to silence the warning, adding this line until we upgrade to
  # rack v. 1.3.5
  gem 'rack-test'
  gem 'simplecov'
  gem 'timecop'
  gem 'vcr'
  gem 'webmock'
  gem 'thor', '~> 0.14.6'
  gem 'approvals'
end
