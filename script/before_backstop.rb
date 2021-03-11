#!/usr/bin/env ruby

layout = ARGV[0]
user = User.find_by(username: "Kappa")

unless layout.nil?
  if layout == 'default'
    user.update!(layout: nil)
  else
    user.update!(layout: layout)
  end
end

Message.find_by(id: 4).update!(unread: true)

post = Post.find_by(id: 33)
post.mark_read(user, at_time: (post.replies.first.created_at - 5.seconds), force: true)

FlatPost.find_by(post_id: 3).update!(updated_at: "2012-09-13 02:00:00")
NewsView.find_by(user: user)&.destroy!
Post.find_by(id: 2).mark_read(user, at_time: "2019-06-22 07:40:11", force: true)
ReportView.find_or_create_by!(user_id: 3).update!(read_at: 3.days.ago.to_date)
