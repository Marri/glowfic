RSpec.describe "Favorites page", :type => :system do
  scenario "User views normal favorites" do
    user = create(:user, username: "usert")
    create(:post, user: user, subject: "user post") # user_post
    post = create(:post, subject: "postt")
    board = create(:board, creator: user, name: "boardt")
    create(:post, board: board, subject: "board post") # board_post
    create(:post, board: board, user: user, subject: "board user post") # board_user_post

    logged_in_user = login
    create(:favorite, user: logged_in_user, favorite: user)
    create(:favorite, user: logged_in_user, favorite: post)
    create(:favorite, user: logged_in_user, favorite: board)

    visit favorites_path

    expect(page).to have_text("Your Favorites")
    expect(page).not_to have_text("boardt Continuity")
    expect(page).not_to have_text("usert User")
    expect(page).not_to have_text("postt Post")
    expect(page).to have_text("user post")
    expect(page).to have_text("board post")
    expect(page).to have_text("board user post")

    click_link "Grouped »"

    expect(page).to have_text("Your Favorites")
    expect(page).to have_text("boardt Continuity")
    expect(page).to have_text("usert User")
    expect(page).to have_text("postt Post")
    expect(page).not_to have_text("user post")
    expect(page).not_to have_text("board post")
    expect(page).not_to have_text("board user post")
  end
end
