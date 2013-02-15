class Field < ActiveRecord::Base
  belongs_to :post

  NATIVE_TYPE_NIL = -1
  NATIVE_TYPE_TEXT = 0
  NATIVE_TYPE_INTEGER = 1
  NATIVE_TYPE_FLOAT = 2 # TODO: Support

  # Updates the value of the field, resetting every typed value column accordingly
  def value=(value)
    if value.nil?
      self.text_value = nil
      self.integer_value = nil
      self.time_value = nil
      self.native_type = -1
    end
    self.text_value = value.to_s
    begin
      self.integer_value = Integer(value)
    rescue ArgumentError
      self.integer_value = nil
    end
    begin
      self.time_value = Time.parse(value.to_s)
    rescue ArgumentError
      self.time_value = nil
    end
    if value.is_a?(Numeric)
      self.native_type = NATIVE_TYPE_INTEGER
    else
      self.native_type = NATIVE_TYPE_TEXT
    end
  end

  def value
    case self.native_type
    when NATIVE_TYPE_INTEGER
      self.integer_value
    when NATIVE_TYPE_NIL
      nil
    else
      self.text_value
    end
  end

  def self.for_post(post)
    result = {}
    Field.where(:post_id => post).each do |field|
      result[field.key] = field.value
    end
    expand_hash(result)
  end

  def self.update_all(post, document)
    document = {} if document.nil?
    changed = false
    document = flatten_hash(document)
    # Update existing fields for this post
    Field.where(:post_id => post).each do |field|
      if document.has_key?(field.key)
        changed = true if field.value != document[field.key]
        field.value = document.delete(field.key)
        field.save!
      else
        changed = true
        field.destroy
      end
    end
    # Create missing fields
    document.each do |key, value|
      changed = true
      Field.create!(:post => post, :key => key, :value => value)
    end
    changed
  end


  # Flattens a hash transforming nested keys into dot-separated identifiers.
  # {'a' => {'b' => 1}} becomes {'a.b' => 1}
  def self.flatten_hash(hash, prefix = [])
    result = {}
    hash.each do |key, value|
      if value.is_a?(Hash)
        result.merge!(Field.flatten_hash(value, prefix + [key]))
      else
        result[(prefix + [key]).join('.')] = value
      end
    end
    result
  end

  # Expands a hash with nested labels into a properly nested hash
  # {'a.b' => 1} becomes {'a' => {'b' => 1}}
  def self.expand_hash(hash)
    result = Hash.new
    hash.each do |key, value|
      destination = result
      key.split('.')[0...-1].each do |subkey|
        destination[subkey] ||= {}
        destination = destination[subkey]
      end
      destination[key.split('.')[-1]] = value
    end
    result
  end
end