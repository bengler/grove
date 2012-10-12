class Location < ActiveRecord::Base
  include PebblePath

  has_and_belongs_to_many :posts, :uniq => true

  after_create :extend_group_access

  private

  def extend_group_access
    GroupLocation.extend_from_ancestors(self)
  end
end
