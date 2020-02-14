new_subject = 'test subject'
reply_user = 'Throne3d'
reply_id = 1024 # we split *after* this reply_id

Post.transaction do
  user = User.find_by(username: reply_user)
  abort("needs user") unless user
  reply = Reply.find_by(user_id: user.id, id: reply_id)
  abort("couldn't find reply") unless reply
  old_post = reply.post
  puts "splitting post #{old_post.id}: #{old_post.subject}, after reply #{reply_id}"

  first_reply = old_post.replies.where('reply_order > ?', reply.reply_order).ordered.first
  other_replies = old_post.replies.where('reply_order > ?', first_reply.reply_order).ordered
  puts "from after reply #{reply.id}, ie starting at + onwards from #{first_reply.inspect}"
  new_post = Post.new
  puts "new_post: marking skip_edited & is_import"
  new_post.skip_edited = new_post.is_import = true

  [:character_id, :icon_id, :character_alias_id, :user_id, :content, :created_at, :updated_at].each do |atr|
    new_value = first_reply.send(atr)
    puts "new_post.#{atr} = #{new_value.inspect}"
    new_post.send(atr.to_s + '=', new_value)
  end

  [:board_id, :section_id, :privacy, :status, :authors_locked].each do |atr|
    new_value = old_post.send(atr)
    puts "new_post.#{atr} = #{new_value.inspect}"
    new_post.send(atr.to_s + '=', new_value)
  end
  puts "new_post.subject = #{new_subject}"
  new_post.subject = new_subject
  puts "new_post.edited_at = #{first_reply.updated_at.inspect}"
  new_post.edited_at = first_reply.updated_at
  new_post.save!
  puts "new post: https://glowfic.com/posts/#{new_post.id}"

  puts "now updating #{other_replies.count} replies to be in post ID #{new_post.id}"
  new_authors = {}
  other_replies.each_with_index do |other_reply, index|
    new_authors[other_reply.user_id] ||= other_reply
    other_reply.update_columns(post_id: new_post.id, reply_order: index)
  end
  puts "-> updated"

  puts "deleting reply converted to post: #{first_reply.inspect}"
  first_reply.destroy!
  puts "-> deleted"

  puts "updating authors:"
  new_authors.each do |user_id, reply|
    next if PostAuthor.where(post_id: new_post.id, user_id: user_id).exists?
    existing = PostAuthor.find_by(post_id: old_post.id, user_id: user_id)
    puts "existing: #{existing.inspect}"
    data = {
      user_id: user_id,
      post_id: new_post.id,
      created_at: reply.created_at,
      updated_at: [existing.updated_at, reply.created_at].max,
      can_owe: existing.can_owe,
      can_reply: existing.can_reply,
      joined: existing.joined,
      joined_at: reply.created_at,
    }
    puts "PostAuthor.create!(#{data}), for #{User.find(user_id).inspect}"
    PostAuthor.create!(data)
  end
  puts "-> new authors created"
  still_valid = (old_post.replies.distinct.pluck(:user_id) + [old_post.user_id]).uniq
  invalid = old_post.post_authors.where.not(user_id: still_valid)
  puts "removing old invalid post authors: #{invalid.inspect}"
  invalid.destroy_all
  puts "-> removed"

  new_last_reply = other_replies.last
  new_post_cached_data = {
    last_reply_id: new_last_reply.id,
    last_user_id: new_last_reply.user_id,
    tagged_at: new_last_reply.updated_at,
  }
  puts "updating new_post columns: #{new_post_cached_data}"
  new_post.update_columns(new_post_cached_data)

  last_reply = old_post.replies.ordered.last
  post_cached_data = {
    last_reply_id: last_reply.id,
    last_user_id: last_reply.user_id,
    tagged_at: last_reply.updated_at,
  }
  puts "updating post columns: #{post_cached_data}"
  old_post.update_columns(post_cached_data)
end