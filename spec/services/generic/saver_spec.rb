require "spec_helper"

RSpec.describe Generic::Saver do
  let (:user) { create(:user) }
  let (:board) { create(:board) }
  let (:allowed) { [:name, :description, coauthor_ids: [], cameo_ids: []] }
  let (:params) { ActionController::Parameters.new({ id: board.id }) }

  it "succeeds on create" do
    board = build(:board)
    params[:board] = { name: "test name" }
    saver = Generic::Saver.new(board, user: user, params: params, allowed_params: allowed)
    expect(saver.create).to eq(true)

    board.reload

    expect(board).not_to be_nil
    expect(board.name).to eq('test name')
  end

  it "succeeds on update" do
    params[:board] = { name: "test name" }
    saver = Generic::Saver.new(board, user: user, params: params, allowed_params: allowed)
    expect(saver.update).to eq(true)
    expect(board.reload.name).to eq('test name')
  end

  it "ignores non-permitted params" do
    params[:board] = { random_thing: 'should be ignored', name: "test name" }
    saver = Generic::Saver.new(board, user: user, params: params, allowed_params: allowed)
    expect(saver.update).to eq(true)
    expect(board.reload.name).to eq('test name')
  end

  it "fails on invalid params" do
    params[:board] = { name: nil }
    saver = Generic::Saver.new(board, user: user, params: params, allowed_params: allowed)
    expect(saver.update).to eq(false)
    expect(board.errors.full_messages).to eq(["Name can't be blank"])
  end
end
