class Location < ActiveRecord::Base
  # The maximum allowed path depth
  MAX_DEPTH = 10

  has_and_belongs_to_many :posts, :uniq => true

  validate :must_not_include_stray_nils, :must_be_valid_uid_path
  validates_presence_of :label_0

  scope :by_path, lambda { |path|
    Location.where(Location.parse_path(path))
  }

  class PathLabelsAccessor
    include Enumerable

    def initialize(location)
      @location = location
    end

    def [](index)
      @location.send(:"label_#{index}")
    end

    def []=(index, value)
      @location.send(:"label_#{index}=", value)
    end

    def each(&block)
      Location::MAX_DEPTH.times do |i|
        break unless label = self[i]
        yield(label)
      end
    end

    def size
      result = 0
      self.each { result += 1}
      result
    end

    def to_s
      to_a.join('.')
    end
  end

  def self.declare!(path)
    attributes = self.parse_path(path)
    path = self.where(attributes).first
    path ||= self.create!(attributes)
  end

  def path
    @path ||= PathLabelsAccessor.new(self)
  end

  # Converts an oid-path to a hash with attributes for
  # this very model. The attributes will always be
  # fully constrained (specify every labels field even
  # if they are nil), unless you terminate the path
  # with an asterisk, e.g.: "realm.blog.thread.*"
  def self.parse_path(path)
    labels = path.split('.')
    result = {}
    (0...MAX_DEPTH).map do |index|
      break if labels[index] == '*'
      result[:"label_#{index}"] = labels[index] || nil
    end
    result
  end

  private

  def must_not_include_stray_nils
    nil_seen = false
    MAX_DEPTH.times do |i|
      if self.path[i].nil?
        nil_seen = true
      else
        errors.add(:base, "Location path has missing labels. (Stray nils within path)") if nil_seen
      end
    end
  end

  def must_be_valid_uid_path
    unless Pebblebed::Uid.valid_path?(self.path.to_s)
      errors.add(:base, "Location path '#{self.path.to_s}' is invalid.")
    end
  end
end
