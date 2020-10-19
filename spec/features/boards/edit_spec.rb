RSpec.feature "Edit a single continuity", type: :feature do
  scenario "Continuity can be edited" do
    board = create(:board, name: "Test board")
    login(board.creator, 'password')
    visit continuity_path(board)
    expect(page).to have_text("Test board")
    click_link "Edit"
    fill_in 'Continuity Name', with: 'Edited board'
    click_button 'Save'
    expect(page).to have_no_selector('.error')
    expect(page).to have_selector('.success', text: 'Continuity updated.')
    expect(page).to have_text("Edited board")
  end
end
