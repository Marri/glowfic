RSpec.describe "Searching posts", :type => :system do
  scenario "Searching a mixture of posts" do
    post = create(:post, subject: 'First post')

    visit search_posts_path

    def perform_search
      within('.search-form') do
        fill_in 'Subject', with: 'post'
      end
      click_button 'Search'

      expect(page).to have_no_selector('.error')
    end

    # check post shows when public
    perform_search
    within('#search_results') do
      expect(page).to have_selector('.post-subject', text: 'First post')
    end

    # check the post is hidden when private
    post.update!(privacy: :private)
    perform_search
    within('#search_results') do
      expect(page).to have_no_selector('.post-subject', text: 'First post')
    end

    # check the post is still hidden when there are two pages of results
    2.upto(26) { |i| create(:post, subject: 'post ' + i.to_s, privacy: :private) }
    perform_search
    within('#search_results') do
      expect(page).to have_no_selector('.post-subject')
    end

    # check a new post shows up
    create(:post, subject: 'Last post') # post2
    perform_search
    within('#search_results') do
      expect(page).to have_selector('.post-subject', count: 1)
      expect(page).to have_selector('.post-subject', text: 'Last post')
    end
  end
end
