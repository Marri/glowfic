module Post::Status
  extend ActiveSupport::Concern

  included do
    enum status: {
      active: 0,
      complete: 1,
      hiatus: 2,
      abandoned: 3,
    }

    after_commit :notify_followers_activity, on: :update

    def on_hiatus?
      hiatus? || (active? && tagged_at < 1.month.ago)
    end

    private

    def notify_followers_activity
      return unless status_before_last_save == 'abandoned'
      NotifyFollowersOfNewPostJob.perform_later(self.id, [], 'active')
    end
  end
end
