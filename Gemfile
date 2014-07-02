source 'https://rubygems.org'

gem 'sinatra'
gem 'sinatra-contrib'
gem 'sinatra-activerecord'
gem 'rack-contrib', :git => 'git://github.com/rack/rack-contrib.git'
gem 'activerecord', :require => 'active_record'
gem 'pg'
gem 'yajl-ruby', :require => "yajl"
gem 'petroglyph'
gem 'pebblebed', '>=0.2.1'
gem 'pebbles-cors', github: 'bengler/pebbles-cors'
gem 'dalli'
gem 'ts_vector_tags'
gem 'rake'
gem 'sanitize', '~> 2.1.0'
gem 'curb'
gem 'pebbles-path', '>=0.0.3'
gem 'pebbles-uid'
gem 'servolux'
gem 'main'
gem "memcache_mock"
gem 'nokogiri', '~> 1.6.1'
gem 'thor', '~> 0.19.1'

# Because of a bug in rack-protection (https://github.com/rkh/rack-protection/commit/a91810fa) that affects
# cors-requests we'll need to get rack-protection from github
# This can safely be changed to the official rubygems version '> 1.2.0' whenever it is released
gem 'rack-protection', :git => 'git://github.com/rkh/rack-protection.git'

group :development, :test do
  gem 'bengler_test_helper', :git => "git://github.com/bengler/bengler_test_helper.git", :require => false
  gem 'rspec', '~> 2.8'
  # a monkeypatch in rack 1.3.4 causes :WFKV_ to be declared twice
  # so to silence the warning, adding this line until we upgrade to
  # rack v. 1.3.5
  gem 'rack-test'
  gem 'simplecov'
  gem 'timecop'
  gem 'vcr'
  gem 'webmock'
  gem 'approvals'
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'rollbar', :require => false
  gem 'unicorn'
end
