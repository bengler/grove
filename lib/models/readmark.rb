class Readmark < ActiveRecord::Base
  belongs_to :location
  belongs_to :post

  before_save :create_location_from_path

  scope :by_path, lambda { |path|
    select("readmarks.*").joins(:location).where(:locations => PebblePath.to_conditions(path)) unless path == '*'
  }

  # Set the current readmark for a user in a given path in an idempotent way. Typically called as the
  # user is reading.
  def self.set!(identity, path, post_id)
    raise ArgumentError, "Invalid path" unless Pebblebed::Uid.valid_path?(path)
    readmark = Readmark.where("owner = ?", identity).by_path(path).first
    readmark ||= Readmark.create!(:owner => identity, :path => path)
    readmark.post_id = post_id
    readmark.recount!
    readmark
  end

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
    Post.by_path("#{self.path}.*").where("posts.id > ?", self.post_id).count
  end

  private

  def self.update_unread_counts(path, post_id, diff)
    Readmark.by_path("^#{path}").where("post_id < ?", post_id).
      update_all("unread_count = unread_count + (#{diff.to_i})")
  end

  def create_location_from_path
    self.location = Location.declare!(@path) if @path
  end
end
