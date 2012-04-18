source 'http://rubygems.org'

gem 'sinatra'
gem 'sinatra-contrib'
gem 'sinatra-activerecord'
gem 'rack-contrib', :git => 'git://github.com/rack/rack-contrib.git'
gem 'activerecord', :require => 'active_record'
gem 'pg'
gem 'yajl-ruby', :require => "yajl"
gem 'petroglyph', :git => 'git://github.com/benglerpebbles/petroglyph.git'
# TODO: This should really be a normal, public version of pebblebed, but right now I'm not getting
# the latest version of Pebblebed from rubygems.org. WFT?
gem 'pebblebed', :git => 'git://github.com/benglerpebbles/pebblebed.git', :branch => 'wildcard-path'
gem 'dalli'
gem 'hupper', :git => 'git://github.com/bengler/hupper.git'
gem 'ts_vector_tags'
gem 'rake'
gem 'unicorn', '~> 4.1.1'
gem 'bengler_test_helper',  :git => "git://github.com/origo/bengler_test_helper.git"
gem 'sanitize'
gem 'pingable'
gem 'o5-logging', :git => "git://github.com/benglerpebbles/o5-logging.git"
gem 'curb'

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
  gem 'approvals'
end
