class NoModNoteError < ApiError
  def initialize(msg="You must provide a reason for your moderator edit.")
    super(msg)
  end
end
