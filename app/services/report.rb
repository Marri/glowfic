# This class is intended to ultimately be used as a parent
# class for both a DailyReport and a MonthlyReport. Until then,
# it does nothing special; see DailyReport.

# TODO consolidate view code; this is not an AR object, so cannot
# use the Viewable concern. This should be abstract enough to work.

class Report < Object
  def self.mark_read(user, at_time:)
    view = view_for(user)

    if view.new_record?
      view.read_at = at_time
      return view.save
    end

    return true if at_time <= view.read_at.to_date
    view.read_at = at_time
    view.save!
  end

  def self.last_read(user)
    view_for(user).read_at
  end

  class << self
    protected

    def view_for(user)
      ReportView.where(user_id: user.id).first_or_initialize
    end
  end
end
