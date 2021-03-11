RSpec.describe UpdateModelJob do
  before(:each) { ResqueSpec.reset! }

  it "crashes on invalid models" do
    expect {
      UpdateModelJob.perform_now('NotClass', {}, {}, nil)
    }.to raise_error(NameError)
  end

  it "crashes on invalid wheres" do
    expect {
      UpdateModelJob.perform_now('Reply', {board_id: 2}, {}, nil)
    }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "crashes on invalid attrs" do
    reply = create(:reply)
    expect {
      UpdateModelJob.perform_now('Reply', {id: reply.id}, {board_id: 2}, nil)
    }.to raise_error(ActiveModel::UnknownAttributeError)
  end

  it "logs an error on missing user param" do
    reply = create(:reply)
    char = create(:character, user: reply.user)
    args = ['Reply', {id: reply.id}, {character_id: char.id}]
    notifier = class_double('ExceptionNotifier').as_stubbed_const
    expect(notifier).to receive(:notify_exception).with(ArgumentError, data: {job: UpdateModelJob.to_s, args: args})
    UpdateModelJob.perform_now(*args)
  end

  it "logs an error on invalid user" do
    reply = create(:reply)
    char = create(:character, user: reply.user)
    user = create(:user)
    user.destroy!
    args = ['Reply', {id: reply.id}, {character_id: char.id}, user.id]
    notifier = class_double('ExceptionNotifier').as_stubbed_const
    expect(notifier).to receive(:notify_exception).with(ActiveRecord::RecordNotFound, data: {job: UpdateModelJob.to_s, args: args})
    UpdateModelJob.perform_now(*args)
  end

  it "does not update tagged_at" do
    reply = create(:reply)
    old_tag = reply.post.tagged_at
    new_char = create(:character, user: reply.user)
    expect(reply.character).to be_nil
    UpdateModelJob.perform_now('Reply', {id: reply.id}, {character_id: new_char.id}, reply.user.id)
    expect(reply.reload.character).to eq(new_char)
    expect(reply.post.reload.tagged_at).to be_the_same_time_as(old_tag)
  end

  it "creates audits" do
    Reply.auditing_enabled = true
    reply = create(:reply)
    new_char = create(:character, user: reply.user)
    time = Time.zone.now
    Timecop.freeze(time) do
      UpdateModelJob.perform_now('Reply', {id: reply.id}, {character_id: new_char.id}, reply.user.id)
    end
    expect(reply.reload.character).to eq(new_char)
    audit = reply.audits.last
    expect(audit.created_at).to be_the_same_time_as(time)
    expect(audit.audited_changes).to eq({"character_id" => [nil, new_char.id]})
    expect(audit.user).to eq(reply.user)
    Reply.auditing_enabled = false
  end
end
