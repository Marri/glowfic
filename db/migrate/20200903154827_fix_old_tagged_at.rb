class FixOldTaggedAt < ActiveRecord::Migration[5.2]
  def change
    execute <<~SQL
      UPDATE posts
      SET tagged_at = replies.updated_at
      FROM replies
      WHERE
        replies.id = posts.last_reply_id
        AND posts.status != #{Post.statuses[:complete]}
        AND posts.last_reply_id IS NOT NULL
        AND NOT (posts.tagged_at = replies.updated_at)
    SQL
  end
end
