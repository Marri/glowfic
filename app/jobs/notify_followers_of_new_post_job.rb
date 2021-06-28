class NotifyFollowersOfNewPostJob < ApplicationJob
  queue_as :notifier

  ACTIONS = ['new', 'join', 'access', 'public']

  def perform(post_id, user_id, action)
    post = Post.find_by(id: post_id)
    return unless post && ACTIONS.include?(action)
    return if post.privacy_private?

    if ['join', 'access'].include?(action)
      user = User.find_by(id: user_id)
      return unless user
    else
      return unless user_id.is_a?(Array)
      users = User.where(id: user_id)
      return unless users
    end

    if action == 'new'
      notify_of_post_creation(post, users)
    elsif action == 'join'
      notify_of_post_joining(post, user)
    elsif action == 'access'
      notify_of_post_access(post, user)
    end
  end

  def notify_of_post_creation(post, users)
    favorites = Favorite.where(favorite: users).or(Favorite.where(favorite: post.board))
    notified = filter_users(post, favorites.select(:user_id).distinct.pluck(:user_id))

    return if notified.empty?

    message = "#{post.user.username} has just posted a new post"
    other_authors = users.reject{|u| u.id == post.user_id}
    message += " with #{other_authors.pluck(:username).join(', ')}" unless other_authors.empty?
    message += " entitled #{post.subject} in the #{post.board.name} continuity. #{ScrapePostJob.view_post(post.id)}"

    notified.each do |user|
      favorited_authors = favorites.where(user: user).where(favorite_type: 'User')
        .joins('INNER JOIN users on users.id = favorites.favorite_id').pluck('users.username')
      title = favorited_authors.present? ? "New post by #{favorited_authors.to_sentence}" : "New post by #{post.user.username}"
      Message.send_site_message(user.id, title, message)
    end
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

  def notify_of_post_access(post, viewer)
    return unless viewer.favorite_notifications? && post.author_ids.exclude?(viewer.id)
    return unless Favorite.where(favorite: post.authors).or(Favorite.where(favorite: post.board)).where(user: viewer).exists?
    favorited_authors = Favorite.where(user: viewer).where(favorite: post.authors)
      .joins('INNER JOIN users on users.id = favorites.favorite_id').pluck('users.username')
    subject = "You now have access to a post"
    subject += " by #{favorited_authors.to_sentence}" if favorited_authors.present?
    subject += " in #{post.board.name}" if Favorite.between(viewer, post.board)

    message = "You have been given access to a post by #{post.joined_authors.ordered.pluck(:username).to_sentence} entitled #{post.subject} "
    message += "in the #{post.board.name} continuity. #{ScrapePostJob.view_post(post.id)}"

    Message.send_site_message(viewer.id, subject, message)
  end

  def self.notification_about(post, user, unread_only: false)
    messages = Message.where(recipient: user, sender_id: 0).where('created_at >= ?', post.created_at)
    messages = messages.unread if unread_only
    messages.find_each do |notification|
      return notification if notification.message.include?(ScrapePostJob.view_post(post.id))
    end
    nil
  end

  private

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

  def blocked_user_ids(post)
    blocked = Block.where(blocked_user_id: post.author_ids).where("hide_them >= ?", Block.hide_thems[:posts])
    blocked = blocked.select(:blocking_user_id).distinct.pluck(:blocking_user_id)
    blocking = Block.where(blocking_user_id: post.author_ids).where("hide_me >= ?", Block.hide_mes[:posts])
    blocking = blocking.select(:blocked_user_id).distinct.pluck(:blocked_user_id)
    (blocked + blocking).uniq
  end
end
