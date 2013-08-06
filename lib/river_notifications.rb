require 'pebblebed'
require_relative 'models/post'

class RiverNotifications < ActiveRecord::Observer
  observe :post

  def self.river
    @river ||= Pebblebed::River.new
  end

  def after_create(post)
    prepare_for_publish(post, :create)
  end

  def after_update(post)
    if post.deleted?
      prepare_for_publish(post, :delete)
    else
      prepare_for_publish(post, :update)
    end
  end

  def after_destroy(post)
    prepare_for_publish(post, :delete)
  end

  def prepare_for_publish(post, event)
    post.paths.each do |path|
      options = {
        :uid => "#{post.klass}:#{path}$#{post.id}",
        :event => event,
        :attributes => post.attributes_for_export
      }
      options[:changed_attributes] = post.changes if event == :update
      publish!(options)
    end
  end

  def publish!(options)
    self.class.river.publish(options)
  end

end
