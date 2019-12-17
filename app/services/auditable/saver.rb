class Auditable::Saver < Generic::Saver
  def update!
    build
    check_audit_comment
    save!
  end

  def check_audit_comment
    @errors.add(:base, "You must provide a reason for your moderator edit.") if @user != @model.user && @model.audit_comment.blank?
  end
end
