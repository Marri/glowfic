class NotifyFollowersOfNewPostJob < ApplicationJob
  queue_as :notifier

  def perform(post_id, user_id)
    post = Post.find_by(id: post_id)
    user = User.find_by(id: user_id)
    return unless post && user
    return if post.privacy_private?

    if post.user_id == user_id
      notify_of_post_creation(post, user)
    else
      notify_of_post_joining(post, user)
    end
  end

  def notify_of_post_creation(post, post_user)
    favorites = Favorite.where(favorite: post_user).or(Favorite.where(favorite: post.board))
    user_ids = favorites.select(:user_id).distinct.pluck(:user_id)
    users = filter_users(post, user_ids)

    return if users.empty?

    message = "#{post_user.username} has just posted a new post entitled #{post.subject} in the #{post.board.name} continuity"
    other_authors = post.authors.where.not(id: post_user.id)
    message += " with #{other_authors.pluck(:username).join(', ')}" if other_authors.exists?
    message += ". #{ScrapePostJob.view_post(post.id)}"

    users.each { |user| Message.send_site_message(user.id, "New post by #{post_user.username}", message) }
  end

  def notify_of_post_joining(post, new_user)
    users = filter_users(post, Favorite.where(favorite: new_user).pluck(:user_id))
    return if users.empty?

    subject = "#{new_user.username} has joined a new thread"
    message = "#{new_user.username} has just joined the post entitled #{post.subject} with "
    message += post.joined_authors.where.not(id: new_user.id).pluck(:username).join(', ')
    message += ". #{ScrapePostJob.view_post(post.id)}"

    users.each do |user|
      next if already_notified_about?(post, user)
      Message.send_site_message(user.id, subject, message)
    end
  end

  def filter_users(post, user_ids)
    user_ids &= PostViewer.where(post: post).pluck(:user_id) if post.privacy_access_list?
    user_ids -= post.author_ids
    user_ids -= blocked_user_ids(post)
    return [] unless user_ids.present?
    User.where(id: user_ids, favorite_notifications: true)
  end

  def already_notified_about?(post, user)
    self.class.notification_about(post, user).present?
  end

  def self.notification_about(post, user, unread_only: false)
    messages = Message.where(recipient: user, sender_id: 0).where('created_at >= ?', post.created_at)
    messages = messages.unread if unread_only
    messages.find_each do |notification|
      return notification if notification.message.include?(ScrapePostJob.view_post(post.id))
    end
    nil
  end

  def blocked_user_ids(post)
    blocked = Block.where(blocked_user_id: post.author_ids).where("hide_them >= ?", Block.hide_thems[:posts])
    blocked = blocked.select(:blocking_user_id).distinct.pluck(:blocking_user_id)
    blocking = Block.where(blocking_user_id: post.author_ids).where("hide_me >= ?", Block.hide_mes[:posts])
    blocking = blocking.select(:blocked_user_id).distinct.pluck(:blocked_user_id)
    (blocked + blocking).uniq
  end
end
