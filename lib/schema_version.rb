# Returns a signature for the current version of the database schema

require 'digest'

module SchemaVersion
  # create a hash for the current schema version
  def self.current
    @version ||= begin
      migrations = ActiveRecord::Base.connection.select_values("select version from schema_migrations")    
      Digest::MD5.hexdigest(migrations.sort.join('-'))[0...10]
    end
  end

  def self.tag_key(key)
    "#{key}$%$schema:#{self.current}"
  end

  def self.untag_key(key)
    key.gsub(/\$\%\$schema\:.*$/, '')
  end

  # add a version hash to memcached keys
  def self.tag_keys(keys)
    keys.map { |key| self.tag_key(key) }
  end

  # Snip a schema tag from cache keys
  def self.untag_keys(keys)
    keys.map { |key| self.untag_key(key) }
  end
end
