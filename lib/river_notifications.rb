require 'pebblebed'
require_relative 'models/post'

class RiverNotifications < ActiveRecord::Observer
  observe :post

  def self.river
    @river ||= Pebblebed::River.new
  end

  def after_create(post)
    publish(post, :create)
  end

  def after_update(post)
    if post.deleted?
      publish(post, :delete)
    else
      publish(post, :update)
    end
  end

  def after_destroy(post)
    publish(post, :delete)
  end

  def publish(post, event)
    post.paths.each do |path|
      options = {
        :uid => "#{post.klass}:#{path}$#{post.id}",
        :event => event,
        :attributes => post.attributes_for_export
      }
      options[:changed_attributes] = post.changes if event == :update
      self.class.river.publish(options)
    end
  end

end
