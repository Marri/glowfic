# frozen_string_literal: true
class MessagesController < ApplicationController
  before_action :login_required
  before_action :editor_setup, only: :new

  def index
    blocked_ids = Block.where(blocking_user: current_user).pluck(:blocked_user_id)
    if params[:view] == 'outbox'
      @page_title = 'Outbox'
      from_table = current_user.sent_messages.where(visible_outbox: true).ordered_by_thread.select('distinct on (thread_id) messages.*')
      from_table = from_table.where.not(recipient_id: blocked_ids).joins(:recipient).where.not(users: {deleted: true})
    else
      @page_title = 'Inbox'
      from_table = current_user.messages.where(visible_inbox: true).ordered_by_thread.select('distinct on (thread_id) messages.*')
      from_table = from_table.where.not(sender_id: blocked_ids).left_outer_joins(:sender).where('users.deleted IS NULL OR users.deleted = false')
    end
    @messages = Message.from(from_table).select('*').order('subquery.id desc').paginate(page: page)
    @view = @page_title.downcase
  end

  def new
    @message = Message.new
    recipient = User.active.find_by_id(params[:recipient_id])
    @message.recipient = recipient unless recipient && current_user.has_interaction_blocked?(recipient)
    @page_title = 'Compose Message'
  end

  def create
    @message = Message.new(permitted_params)
    @message.sender = current_user
    set_message_parent(params[:parent_id]) if params[:parent_id].present?

    if params[:button_preview]
      @messages = Message.where(thread_id: @message.thread_id).ordered_by_id if @message.thread_id
      editor_setup
      @page_title = 'Compose Message'
      render :preview and return
    end

    if flash.now[:error].nil? && @message.save
      flash[:success] = "Message sent."
      redirect_to messages_path(view: 'inbox') and return
    end

    cached_error = flash.now[:error] # preserves errors from setting an invalid parent
    flash.now[:error] = {
      message: "Message could not be sent because of the following problems:",
      array: @message.errors.full_messages
    }
    flash.now[:error][:array] << cached_error if cached_error.present?
    editor_setup
    @page_title = 'Compose Message'
    render :new
  end

  def show
    unless (message = Message.find_by_id(params[:id]))
      flash[:error] = "Message could not be found."
      redirect_to messages_path(view: 'inbox') and return
    end

    if message.sender&.deleted? || message.recipient.deleted?
      flash[:error] = "Message could not be found."
      redirect_to messages_path(view: 'inbox') and return
    end

    unless message.visible_to?(current_user)
      flash[:error] = "You do not have permission to view that message."
      redirect_to messages_path(view: 'inbox') and return
    end

    @page_title = message.unempty_subject
    @box = message.box(current_user)

    @messages = Message.where(thread_id: message.thread_id).ordered_by_id
    if @messages.any? { |m| m.recipient_id == current_user.id && m.unread? }
      @messages.each do |m|
        next unless m.unread?
        next unless m.recipient_id == current_user.id
        m.update(unread: false, read_at: m.read_at || Time.zone.now)
      end
    end
    @message = Message.new
    set_message_parent(message.last_in_thread)
    editor_setup
  end

  def mark
    box = nil
    messages = Message.where(id: params[:marked_ids]).select do |message|
      box ||= message.box(current_user)
      message.visible_to?(current_user)
    end

    if params[:commit] == "Mark Read"
      messages.each do |message|
        next unless message.recipient_id == current_user.id
        message.update(unread: false, read_at: message.read_at || Time.zone.now)
      end
    elsif params[:commit] == "Mark Unread"
      messages.each do |message|
        next unless message.recipient_id == current_user.id
        message.update(unread: true)
      end
    elsif params[:commit] == "Delete"
      messages.each do |message|
        box_attr = "visible_#{box}"
        user_id_attr = (box == 'inbox') ? 'recipient_id' : 'sender_id'
        Message.where(thread_id: message.thread_id, "#{user_id_attr}": current_user.id).each do |thread_message|
          thread_message.update(box_attr => false, unread: false, read_at: thread_message.read_at || Time.zone.now)
        end
      end
    else
      flash[:error] = "Could not perform unknown action."
      redirect_to messages_path and return
    end

    flash[:success] = "Messages updated."
    redirect_to messages_path(view: box || 'inbox')
  end

  private

  def editor_setup
    use_javascript('messages')
    unless @message.try(:parent)
      recent_ids = Message.where(sender_id: current_user.id).order(Arel.sql('MAX(id) desc')).limit(5).group(:recipient_id).pluck(:recipient_id)
      base_users = User.active.where.not(id: [current_user.id] + current_user.user_ids_blocked_interaction)
      recents = base_users.where(id: recent_ids).pluck(:username, :id).sort_by{|x| recent_ids.index(x[1]) }
      users = base_users.ordered.pluck(:username, :id)
      @select_items = if recents.present?
        {:'Recently messaged' => recents, :'Other users' => users}
      else
        {Users: users}
      end
    end
  end

  def set_message_parent(parent_id)
    @message.parent = Message.find_by_id(parent_id)
    unless @message.parent.present?
      @message.parent = nil
      flash.now[:error] = "Message parent could not be found."
      return
    end

    unless @message.parent.visible_to?(current_user)
      @message.parent = nil
      flash.now[:error] = "You do not have permission to reply to that message."
      return
    end

    @message.thread_id = @message.parent.thread_id
    @message.recipient_id = @message.parent.user_ids.detect { |id| id != current_user.id }
  end

  def permitted_params
    params.fetch(:message, {}).permit(
      :recipient_id,
      :subject,
      :message,
    )
  end
end
