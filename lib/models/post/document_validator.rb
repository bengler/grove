class DocumentValidator < ActiveModel::Validator
  def validate(record)
    validate_field(record, :document)
    validate_field(record, :external_document)
  end

  def validate_field(record, field)
    value = record.send(field)
    if value.present? && value.class != Hash
      record.errors[:base] << "The `#{field}` must be a hash."
    end
  end
end