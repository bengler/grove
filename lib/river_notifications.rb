require 'pebblebed'
require_relative 'models/post'

class RiverNotifications < ActiveRecord::Observer
  observe :post

  def self.river
    river = Pebblebed::River.new
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
    self.class.river.publish(:event => event, :uid => post.uid, :attributes => post.attributes.update('document' => post.merged_document))
  end

end
