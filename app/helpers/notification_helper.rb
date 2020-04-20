module NotificationHelper
  def subject_for_type(notification_type)
    case notification_type
    when 'import_success'
      'Post import succeeded'
    when 'import_fail'
      'Post import failed'
    when 'new_favorite_post'
      'An author you favorited has written a new post'
    when 'joined_favorite_post'
      'An author you favorited has joined a post'
    end
  end
end
