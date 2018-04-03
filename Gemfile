source 'https://rubygems.org'

gem 'sinatra', '~> 1.4.7'
gem 'sinatra-contrib', '~> 1.4.7', require: false
gem 'sinatra-activerecord', '~> 2.0.10'
gem 'rack', '~> 1.6.4'
gem 'rack-contrib', '~> 1.4.0'

# tests will fail if you upgrade AR to 4.2.7.1 or beyond
gem 'activerecord', '~> 4.1.16', require: 'active_record'

gem 'rails-observers', '~> 0.1', require: false
gem 'pg', '~> 0.18.1'
gem 'postgres_ext', '~> 2.4.1'
gem 'jbuilder', '~> 2.3.2'
gem 'tilt-jbuilder', '~> 0.7.0', require: 'sinatra/jbuilder'
gem 'yajl-ruby', '~> 1.3.1', :require => "yajl"
gem 'petroglyph', '~> 0.0.7'

gem 'pebblebed', '~> 0.4.4'

gem 'pebbles-cors', :git => 'https://github.com/bengler/pebbles-cors'
gem 'dalli', '~> 2.7.0'
gem 'ts_vector_tags', '~> 0.0.11'
gem 'rake', '~> 0.9.2.2'
gem 'sanitize', '~> 2.1.0'
gem 'curb', '~> 0.9.3'
gem 'pebbles-path', '~> 0.0.3'
gem 'pebbles-uid', '~> 0.0.22'
gem 'pebbles-river', '~> 0.2.0'
gem 'servolux', '~> 0.10.0'
gem 'mercenary', '~> 0.3.4'
gem 'memcache_mock', '~> 0.0.11'
gem 'nokogiri', '~> 1.8.1'
gem 'crack', '~> 0.4.2'
gem 'main', '~> 6.1.0'
gem 'ar-multidb', '~> 0.1.13'
gem 'amq-protocol', '~> 1.9.2'

# For console
gem 'pry', '~> 0.10.1'

group :development, :test do
  gem 'rspec', '~> 2.9'
  gem 'simplecov', '~> 0.6.4'
  gem 'timecop', '~> 0.3.5'
  gem 'vcr', '~> 2.1.1'
  gem 'webmock', '~> 1.8.7'
  gem 'approvals', '~> 0.0.6'
  gem 'its', '~> 0.2.0'
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'rollbar', '~> 0.12.15', :require => false
  gem 'unicorn', '~> 4.8.3'
end
