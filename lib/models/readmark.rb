class Readmark < ActiveRecord::Base
  belongs_to :location

  before_save :create_location_from_path

  scope :by_path, lambda { |path|
    select("readmarks.*").joins(:location).where(:locations => Location.parse_path(path)) unless path == '*'
  }

  def path=(value)
    @path = value
  end

  def path
    @path || self.location.path.to_s
  end

  def self.post_added(path, post_id)
    update_unread_counts(path, post_id, +1)
  end

  def self.post_removed(path, post_id)
    update_unread_counts(path, post_id, -1)
  end

  def recount!
    self.unread_count = count_actual_unread
    self.save!
  end

  def count_actual_unread 
    Post.by_path("#{self.path}.*").where("posts.id > ?", self.last_read_post_id).count
  end

  private

  def self.update_unread_counts(path, post_id, diff)
    Readmark.by_path("^#{path}").where("last_read_post_id < ?", post_id).
      update_all("unread_count = unread_count + (#{diff.to_i})")
  end

  def create_location_from_path    
    self.location = Location.declare!(@path) if @path
  end
end
