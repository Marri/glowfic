module Viewable
  extend ActiveSupport::Concern

  included do
    def mark_read(user, at_time: nil, force: false)
      view = view_for(user)

      if view.new_record?
        view.read_at = at_time || Time.now.in_time_zone
        return view.save
      end

      return view.update(read_at: Time.now.in_time_zone) unless at_time.present?
      return true if view.read_at && at_time <= view.read_at && !force
      view.update!(read_at: at_time)
    end

    def ignore(user)
      view_for(user).update(ignored: true)
    end

    def unignore(user)
      view_for(user).update(ignored: false)
    end

    def ignored_by?(user)
      view_for(user).ignored
    end

    def last_read(user)
      view_for(user).read_at
    end

    def reload
      @view = nil
      @first_unread = nil
      super
    end

    private

    def view_for(user)
      @view ||= views.where(user_id: user.id).first_or_initialize
    end
  end
end
