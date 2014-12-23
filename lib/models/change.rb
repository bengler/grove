class Change < ActiveRecord::Base

  belongs_to :post

  validates :kind,
    inclusion: {
      in: %w(create update delete),
      message: "kind must be one of create, update or delete"
    }

  before_update :raise_immutability_error
  before_destroy :raise_immutability_error

  def self.by_uid(uid)
    klass, path, id = Pebbles::Uid.parse(uid)
    scope = self
    scope = scope.by_path(path) if path
    scope = scope.where("post_id in (select id from posts where klass in (?))",
      klass.split('|')) unless klass == '*'
    scope = scope.where("post_id = ?", id.to_i) if id and id != '' and id != '*'
    scope
  end

  def self.by_path(path)
    conditions = Pebbles::Path.to_conditions(path)
    if conditions.any?
      locations = Location.arel_table
      locations_posts = Arel::Table.new('locations_posts')
      subquery = locations_posts.project(:post_id).
        join(locations).on(locations[:id].eq(locations_posts[:location_id]))
      conditions.each do |column, value|
        if value.respond_to?(:to_ary)
          subquery.where(locations[column].in(value))
        else
          subquery.where(locations[column].eq(value))
        end
      end
      where(self.arel_table[:post_id].in(subquery))
    elsif path == '*'
      where('true')
    else
      where('false')
    end
  end

  def uid
    self.post.try(:uid)
  end

  private

    def raise_immutability_error
      raise RuntimeError, "Change record cannot be updated"
    end

end
