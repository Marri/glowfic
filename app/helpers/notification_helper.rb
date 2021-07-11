module NotificationHelper
  NOTIFICATION_MESSAGES = {
    'import_success'       => 'Post import succeeded',
    'import_fail'          => 'Post import failed',
    'new_favorite_post'    => 'An author you favorited has written a new post',
    'joined_favorite_post' => 'An author you favorited has joined a post',
  }

  def subject_for_type(notification_type)
    NOTIFICATION_MESSAGES[notification_type]
  end
end
