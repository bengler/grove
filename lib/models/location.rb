class Location < ActiveRecord::Base
  include PebblePath

  has_and_belongs_to_many :posts, :uniq => true
end
