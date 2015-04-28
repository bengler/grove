$:.unshift(File.dirname(__FILE__))

require 'sinatra/activerecord/rake'
require_relative 'config/environment'

# TODO: This exists only so CI server will find the task. Change CI
#   script so we don't need it.
namespace :db do
  namespace :test do
    desc "Prepare test database."
    task :prepare
  end
end

namespace :river do
  desc "put all posts into the river with event 'exists'. e.g. bx rake river:put_existing[area51,post.event]"
  task :put_existing, [:realm, :klass] do |t, args|
    require 'logger'

    LOGGER ||= Logger.new(STDOUT)

    river = Pebbles::River::River.new
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
