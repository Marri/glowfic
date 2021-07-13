# frozen_string_literal: true
class ReportsController < ApplicationController
  include DateSelectable

  def index
  end

  REPORT_TYPES = ['daily', 'monthly']

  def show
    @report_type = REPORT_TYPES.detect {|x| x == params[:id] }
    unless @report_type
      flash[:error] = "Could not identify the type of report."
      redirect_to reports_path
    end

    @page_title = params[:id].capitalize + " Report"
    @hide_quicklinks = true
    @day = calculate_day

    if logged_in?
      @opened_posts = Post::View.where(user_id: current_user.id).select([:post_id, :read_at, :ignored])
      @board_views = BoardView.where(user_id: current_user.id).select([:board_id, :ignored])
      @opened_ids = @opened_posts.map(&:post_id)

      DailyReport.mark_read(current_user, at_time: @day) if !current_user.ignore_unread_daily_report? && @day.to_date < Time.zone.now.to_date
    end

    if @report_type == 'daily'
      @new_today = params[:new_today].present?
      @posts = DailyReport.new(@day).posts(sort, @new_today)
      @posts = posts_from_relation(@posts, max: !@new_today)
      replies_on_day = Reply.where(created_at: @day.beginning_of_day..@day.end_of_day)
      @reply_counts = replies_on_day.group(:post_id).count
      first_for_day = replies_on_day.order(post_id: :asc, created_at: :asc)
      first_for_day = first_for_day.pluck(Arel.sql('DISTINCT ON (post_id) replies.post_id, replies.id, replies.created_at'))
      first_for_day = first_for_day.to_h { |pluck| [pluck[0], { id: pluck[1], klass: Reply, created_at: pluck[2] }] }
      @link_targets = @posts.to_h{ |post| [post.id, linked_for(post, first_for_day[post.id])] }
    end
  end

  private

  def linked_for(post, reply)
    if post.created_at.to_date == @day.to_date || reply.nil?
      {id: post.id, klass: Post, created_at: post.created_at}
    else
      reply
    end
  end

  def sort
    @sort ||= case params[:sort]
      when 'subject'
        Arel.sql('LOWER(subject)')
      when 'continuity'
        Arel.sql('LOWER(max(boards.name)), tagged_at desc')
      else
        {first_updated_at: :desc}
    end
  end
end
