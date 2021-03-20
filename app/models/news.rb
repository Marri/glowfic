class News < ApplicationRecord
  belongs_to :user, inverse_of: :news, optional: false

  validates :content, presence: true

  def editable_by?(user)
    return false unless user
    return true if user.id == user_id
    user.has_permission?(:edit_news)
  end

  def deletable_by?(user)
    return false unless user
    return true if user.id == user_id
    user.has_permission?(:delete_news)
  end

  def mark_read(user)
    view = NewsView.where(user_id: user.id).first_or_initialize

    if view.new_record?
      view.news = self
      return view.save
    end

    return true if view.news_id > self.id
    view.update!(news: self)
  end

  def self.num_unread_for(user)
    return 0 unless user

    view = NewsView.find_by(user_id: user.id)
    return News.count unless view

    News.where('id > ?', view.news_id).count
  end
end
