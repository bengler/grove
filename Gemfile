source 'http://rubygems.org'

gem 'sinatra'
gem 'sinatra-contrib'
gem 'sinatra-activerecord'
gem 'rack-contrib', :git => 'git://github.com/rack/rack-contrib.git'
gem 'activerecord', :require => 'active_record'
gem 'pg'
gem 'yajl-ruby', :require => "yajl"
gem 'petroglyph', :git => 'git://github.com/benglerpebbles/petroglyph.git'
gem 'pebblebed', '>=0.0.6'
gem 'dalli'
gem 'hupper', :git => 'git://github.com/origo/hupper.git'
gem 'ts_vector_tags'
gem 'rake'
gem 'unicorn', '~> 4.1.1'
gem 'bengler_test_helper',  :git => "git://github.com/origo/bengler_test_helper.git"
gem 'sanitize'

group :development, :test do
  gem 'rspec', '~> 2.8'
  # a monkeypatch in rack 1.3.4 causes :WFKV_ to be declared twice
  # so to silence the warning, adding this line until we upgrade to
  # rack v. 1.3.5
  gem 'rack-test'
  gem 'simplecov'
  gem 'capistrano', '~> 2.9.0'
  gem 'capistrano-bengler', :git => "git@github.com:origo/capistrano-bengler.git"
  gem 'timecop'
  gem 'vcr'
  gem 'webmock'
end
