module Concealable
  extend ActiveSupport::Concern

  included do
    enum privacy: {
      public: 0,
      private: 1,
      access_list: 2,
      registered: 3
    }, _prefix: true

    after_commit :notify_followers_privacy, on: :update

    def visible_to?(user)
      # does not support access lists at this time
      return true if privacy_public?
      return false unless user
      return true if privacy_registered?
      return true if user.admin?
      user.id == user_id
    end

    def notify_followers_privacy
      return unless saved_change_to_privacy?
      change = saved_change_to_privacy
      if ['access_list', 'private'].include?(change[0]) && ['public', 'registered'].include?(change[1])
        NotifyFollowersOfNewPostJob.perform_later(self.id, [], 'public')
      elsif change[0] == 'private' && change[1] == 'access_list'
        viewers.each do |viewer|
          NotifyFollowersOfNewPostJob.perform_later(self.id, viewer.id, 'access')
        end
      end
    end
  end
end
