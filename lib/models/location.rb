class Location < ActiveRecord::Base
  include PebblePath

  has_and_belongs_to_many :posts, :uniq => true

  def self.declare!(path)
    raise ArgumentError, "Path must be valid" unless Pebblebed::Uid.valid_path?(path)
    attributes = PebblePath.detect(path)
    path = self.where(attributes).first
    path ||= self.create!(attributes)
  end

end
