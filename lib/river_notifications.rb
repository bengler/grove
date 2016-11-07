require 'pebblebed'
require_relative 'models/post'

class RiverNotifications < ActiveRecord::Observer

  observe Post

  def self.river
    @river ||= Pebbles::River::River.new
  end

  def after_create(object)
    if should_publish?(object)
      prepare_for_publish(object, :create)
    end
    nil
  end

  def after_update(object)
    if should_publish?(object)
      if object.deleted?
        prepare_for_publish(object, :delete, :soft_deleted => true)
      else
        prepare_for_publish(object, :update)
      end
    end
    nil
  end

  def after_destroy(object)
    if should_publish?(object)
      prepare_for_publish(object, :delete)
    end
    nil
  end

  def publish!(params)
    self.class.river.publish(params)
  end

  private

    def should_publish?(object)
      if object.is_a?(Post)
        return !object.skip_river_notification_on_save
      else
        return false
      end
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

end
