RSpec.describe "Post stats", :type => :system do
  scenario "User views a stats page" do
    post = create(:post, subject: "stats post test")
    character = create(:character, user: post.user, name: "statchar")
    create_list(:reply, 3, post: post, user: post.user, character: character)

    visit stats_post_path(post)

    expect(page).to have_text("Metadata: stats post test")
    expect(page).to have_text("statchar (3 times)")
  end
end
