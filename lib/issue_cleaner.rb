# This is a one-off class which does closes all unresolved Velkomat issues of 2012
# The reason for this cleanup is that we wrongly included year in the post.issue external_id.
# If you read this, and the current date is later than March 2013, you may delete this code.
class IssueCleaner

  def self.run
    issues = Post.where("klass = ? and external_id like ?", 'post.issue', 'unpaid_membership_2012_%').with_tags_query('!closed')
    oids = []
    issues.each do |issue|
      issue_update = Post.create!(update_attributes(issue.uid))
      oids << issue_update.id
    end
    puts oids.inspect
  end

  def self.update_attributes(issue_uid)
    {
      :document => {
        'state' => 'resolved',
        'body' => 'Issue is no longer relevant because a new issue has been created in 2013.'
      },
      :realm => 'dna',
      :canonical_path => issue_uid.sub('post.issue:', '').sub('$', '.'),
      :klass => 'post.issue_update',
      :restricted => true,
      :document_updated_at => Time.now
    }
  end

end