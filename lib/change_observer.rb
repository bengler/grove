require 'pebblebed'

require_relative 'models/post'

class ChangeObserver < ActiveRecord::Observer

  observe :post

  def after_create(record)
    if record.is_a?(Post)
      Change.create!(kind: 'create', post: record, time: Time.now)
    end
  end

  def after_update(record)
    if record.is_a?(Post)
      case record.changes['deleted']
        when [false, true]
          Change.create!(kind: 'delete', post: record, time: Time.now)
        when [true, false]
          Change.create!(kind: 'create', post: record, time: Time.now)
        else
          Change.create!(kind: 'update', post: record, time: Time.now)
      end
    end
  end

end