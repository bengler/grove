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
      prepare_for_publish(post, :delete, :soft_deleted => true)
    else
      prepare_for_publish(post, :update)
    end
  end

  def after_destroy(post)
    prepare_for_publish(post, :delete)
  end

  def prepare_for_publish(post, event, options = {})
    post.paths.each do |path|
      params = {
        :uid => "#{post.klass}:#{path}$#{post.id}",
        :event => event,
        :attributes => post.attributes_for_export
      }
      params[:changed_attributes] = post.changes if event == :update
      params[:soft_deleted] = true if options[:soft_deleted]
      publish!(params)
    end
  end

  def publish!(params)
    self.class.river.publish(params)
  end

end
