require 'pebblebed'
require_relative 'models/post'

class RiverNotifications < ActiveRecord::Observer
  observe :post

  def after_create(post)
    publish(post, :create)
  end

  def after_update(post)
    publish(post, :update)
  end

  def after_destroy(post)
    publish(post, :delete)
  end

  def publish(post, event)
    Pebblebed::River.publish(:event => event, :uid => post.uid, :attributes => post.attributes)
  end

end
