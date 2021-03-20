class UserMailer < AsyncMailer
  def post_has_new_reply(user_id, reply_id)
    return unless (@reply = Reply.find_by_id(reply_id))

    @subject = "New reply in the thread #{@reply.post.subject}"
    @user = User.find_by_id(user_id)
    mail(to: @user.email, subject: @subject)
  end

  def password_reset_link(password_reset_id)
    @subject = "Password Reset Link"
    @password_reset = PasswordReset.find(password_reset_id)
    mail(to: @password_reset.user.email, subject: @subject)
  end

  def new_message(message_id)
    @message = Message.find(message_id)
    @subject = "New message from #{@message.sender_name}: #{@message.unempty_subject}"
    mail(to: @message.recipient.email, subject: @subject)
  end
end
