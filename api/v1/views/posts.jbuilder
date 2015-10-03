raw, exclude_attributes = @raw, @exclude_attributes  # Alias for performance

json.posts do
  json.array! @posts do |post|
    if post
      json.post do
        json.(post, :uid, :created_by, :created_at, :updated_at, :deleted,
          :tags, :external_id, :restricted, :published, :conflicted,
          :protected, :version)
        json.id post.uid
        if raw
          json.document post.document
          json.external_document post.external_document
          unless @exclude_attributes.include?('occurrences')
            json.occurrences post.occurrences
          end
        else
          json.document post.merged_document(include_occurrences:
            !exclude_attributes.include?('occurrences'))
        end
        unless @exclude_attributes.include?('paths')
          json.(post, :paths)
        end
        unless @exclude_attributes.include?('sensitive') and
          @exclude_attributes.include?('may_edit')
          editable = post.editable_by?(current_identity)
          json.may_edit editable
          if editable
            json.sensitive post.sensitive
          end
        end
      end
    end
  end
end
json.pagination do
  json.next_cursor @next_cursor
  json.limit @limit
end
