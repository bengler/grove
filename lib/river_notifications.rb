require 'pebblebed'
require_relative 'models/post'

class RiverNotifications < ActiveRecord::Observer

  observe Post

  def self.river
    @river ||= Pebbles::River::River.new
  end

  def after_create(object)
    if object.is_a?(Post)
      prepare_for_publish(object, :create)
    end
  end

  def after_update(object)
    if object.is_a?(Post)
      if object.deleted?
        prepare_for_publish(object, :delete, :soft_deleted => true)
      else
        prepare_for_publish(object, :update)
      end
    end
  end

  def after_destroy(object)
    if object.is_a?(Post)
      prepare_for_publish(object, :delete)
    end
  end

  def publish!(params)
    self.class.river.publish(params)
  end

  private

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
        LOGGER.info("published #{params[:uid]}")
      end
    end

end
