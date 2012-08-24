class DocumentValidator < ActiveModel::Validator
  def validate(record)
    return if record.document.nil?

    unless record.document.class == Hash
      record.errors[:base] << "The document must be a hash."
    end
  end
end
