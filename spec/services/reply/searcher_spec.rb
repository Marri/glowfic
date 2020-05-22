require "spec_helper"

RSpec.describe Reply::Searcher do
  it "finds all when no arguments given" do
    create_list(:reply, 4)
    results = Reply::Searcher.new(templates: [], users: []).search({})
    expect(results).to match_array(Reply.all)
  end

  it "filters by author" do
    replies = create_list(:reply, 4)
    filtered_reply = replies.last
    results = Reply::Searcher.new(templates: [], users: []).search({ author_id: filtered_reply.user_id })
    expect(results).to match_array([filtered_reply])
  end

  it "filters by icon" do
    create(:reply, with_icon: true)
    reply = create(:reply, with_icon: true)
    results = Reply::Searcher.new(templates: [], users: []).search({ icon_id: reply.icon_id })
    expect(results).to match_array([reply])
  end

  it "filters by character" do
    create(:reply, with_character: true)
    reply = create(:reply, with_character: true)
    results = Reply::Searcher.new(templates: [], users: []).search({ character_id: reply.character_id })
    expect(results).to match_array([reply])
  end

  it "filters by string" do
    reply = create(:reply, content: 'contains seagull')
    cap_reply = create(:reply, content: 'Seagull is capital')
    create(:reply, content: 'nope')
    results = Reply::Searcher.new(templates: [], users: []).search({ subj_content: 'seagull' })
    expect(results).to match_array([reply, cap_reply])
  end

  it "filters by exact match" do
    create(:reply, content: 'contains forks')
    create(:reply, content: 'Forks is capital')
    reply = create(:reply, content: 'Forks High is capital')
    create(:reply, content: 'Forks high is kinda capital')
    create(:reply, content: 'forks High is different capital')
    create(:reply, content: 'forks high is not capital')
    create(:reply, content: 'Forks is split from High')
    create(:reply, content: 'nope')
    results = Reply::Searcher.new(templates: [], users: []).search({ subj_content: '"Forks High"' })
    expect(results).to match_array([reply])
  end

  it "filters by post" do
    replies = create_list(:reply, 4)
    filtered_reply = replies.last
    results = Reply::Searcher.new(templates: [], users: []).search({}, post: filtered_reply.post)
    expect(results).to match_array([filtered_reply])
  end

  it "filters by continuity" do
    continuity_post = create(:post, num_replies: 1)
    create(:post, num_replies: 1) # wrong post
    filtered_reply = continuity_post.replies.last
    results = Reply::Searcher.new(templates: [], users: []).search({ board_id: continuity_post.board_id })
    expect(results).to match_array([filtered_reply])
  end

  it "filters by template" do
    character = create(:template_character)
    templateless_char = create(:character)
    reply = create(:reply, character: character, user: character.user)
    create(:reply, character: templateless_char, user: templateless_char.user)
    results = Reply::Searcher.new(templates: [], users: []).search({ template_id: character.template_id })
    expect(results).to match_array([reply])
  end

  it "sorts by created desc" do
    reply = create(:reply)
    reply2 = Timecop.freeze(reply.created_at + 2.minutes) do
      create(:reply)
    end
    results = Reply::Searcher.new(templates: [], users: []).search({ sort: 'created_new' })
    expect(results).to eq([reply2, reply])
  end

  it "sorts by created asc" do
    reply = create(:reply)
    reply2 = Timecop.freeze(reply.created_at + 2.minutes) do
      create(:reply)
    end
    results = Reply::Searcher.new(templates: [], users: []).search({ sort: 'created_old' })
    expect(results).to eq([reply, reply2])
  end
end
