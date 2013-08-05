require 'pebblebed'
require_relative 'models/post'

class RiverNotifications < ActiveRecord::Observer
  observe :post

  def self.river
    @river ||= Pebblebed::River.new
  end

  def after_create(post)
    puz(post, :create)
  end

  def after_update(post)
    if post.deleted?
      puz(post, :delete)
    else
      puz(post, :update)
    end
  end

  def after_destroy(post)
    puz(post, :delete)
  end

  def puz(post, event)
    post.paths.each do |path|
      options = {
        :uid => "#{post.klass}:#{path}$#{post.id}",
        :event => event,
        :attributes => post.attributes_for_export
      }
      options[:changed_attributes] = post.changes if event == :update
      puts "  options: #{options}"
      self.class.river.publish(options)
    end
  end

end
