$:.unshift(File.dirname(__FILE__))

require 'sinatra/activerecord/rake'
require 'bengler_test_helper/tasks'

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

namespace :db do

  desc "bootstrap db user, recreate, run migrations"
  task :bootstrap do
    name = "grove"
    `createuser -sdR #{name}`
    `createdb -O #{name} #{name}_development`
    Rake::Task['db:migrate'].invoke
    Rake::Task['db:test:prepare'].invoke
  end

  task :migrate => :environment do
    Rake::Task["db:structure:dump"].invoke
  end

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
