$:.unshift(File.dirname(__FILE__))

require 'sinatra/activerecord/rake'
require 'bengler_test_helper/tasks' if ['development', 'test'].include?(ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development')

task :environment do
  require 'config/environment'
end

namespace :bagera do
  desc "trigger initial delta migrations"
  task :trigger_delta => :environment do
    require 'logger'

    LOGGER ||= Logger.new(STDOUT)

    LOGGER.info "Beginning symlink/import process for #{Post.where(:klass => 'post.event').count} events."

    river = Pebblebed::River.new
    Post.where(:klass => 'post.event').find_each do |post|
      begin
        river.publish(:event => 'create', :uid => post.uid, :attributes => post.attributes.update('document' => post.merged_document))
      rescue RuntimeError => e
        LOGGER.warn "Error publishing post to river."
        LOGGER.error e
      else
        LOGGER.info "Published #{post.uid} to river with fake 'create' event."
      end
    end

  end
end

namespace :river do
  desc "put all posts into the river with event 'exists'. e.g. bx rake river:put_existing[area51,post.event]"
  task :put_existing, [:realm, :klass] => :environment do |t, args|
    require 'logger'

    LOGGER ||= Logger.new(STDOUT)

    river = Pebblebed::River.new
    scope = Post.where(:restricted => false)
    scope = scope.where(:realm => args[:realm]) if args[:realm]
    scope = scope.where(:klass => args[:klass]) if args[:klass]
    LOGGER.info "Touching all #{scope.count} unrestricted posts for realm #{args[:realm] or '*'} and class #{args[:klass] or '*'}"

    scope.find_each do |post|
      begin
        river.publish(:event => 'exists', :uid => post.uid, :attributes => post.attributes_for_export)
      rescue RuntimeError => e
        LOGGER.warn "Error publishing post to river."
        LOGGER.error e
      else
        LOGGER.info "Published #{post.uid} to river with 'exists' event."
      end
    end
  end
end


namespace :db do
  desc "bootstrap db user, recreate, run migrations"
  task :bootstrap do
    name = "grove"
    `createuser -sdR #{name}`
    `createdb -O #{name} #{name}_development`
    Rake::Task['db:migrate'].invoke
    Rake::Task['db:test:prepare'].invoke
  end

  task :migrate => :environment

  desc "nuke db, recreate, run migrations"
  task :nuke do
    name = "grove"
    `dropdb #{name}_development`
    `createdb -O #{name} #{name}_development`
    Rake::Task['db:migrate'].invoke
    Rake::Task['db:test:prepare'].invoke
  end

  desc "add seed data to database"
  task :seed => :environment do
    require_relative './db/seeds'
  end
end
