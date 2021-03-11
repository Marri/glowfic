RSpec.describe "Show a list of galleries", :type => :system do
  def setup_sample_data
    user = create(:user, username: 'Test user', password: 'known')
    create(:icon, user: user) # galleryless icon
    create(:gallery, user: user, name: 'Empty gallery')

    icon1 = create(:icon, user: user)
    create(:gallery, user: user, name: 'Gallery1', icons: [icon1])

    icon2 = create(:icon, user: user)
    group1 = create(:gallery_group, name: 'Test group B')
    group2 = create(:gallery_group, name: 'Test group A')
    group3 = create(:gallery_group, name: 'Test group C')
    create(:gallery, user: user, name: 'Gallery2', icons: [icon2], gallery_groups: [group1, group3, group2])

    user
  end

  def expect_gallery_of(name, size, tags=[])
    gallery_row = find('tr') { |x| x.has_selector?('.gallery-name a', exact_text: name) }
    within(gallery_row) do
      expect(page).to have_selector('.gallery-icon-count', exact_text: size.to_s)
      tag_box = page.all('.tag-box').first
      seen_tags = (tag_box.try(:all, '.tag-item-link') || []).map(&:text)
      expect(seen_tags).to eq(tags)
    end
  end

  def gallery_row_for(name)
    find('tr') { |x| x.has_selector?('.gallery-name', exact_text: name) }
  end

  scenario "View a user's list of galleries while logged out" do
    user = setup_sample_data
    visit user_galleries_path(user_id: user.id)

    expect(page).to have_selector('th', text: "Test user's Galleries")
    expect(page).to have_no_selector('.gallery-new')

    within('#content tbody') do
      expect(page).to have_no_selector('.gallery-add')
      expect(page).to have_no_selector('.gallery-edit')
      expect(page).to have_no_selector('.gallery-delete')

      expect_gallery_of('[Galleryless]', 1)
      expect_gallery_of('Empty gallery', 0)
      expect_gallery_of('Gallery1', 1)
      expect_gallery_of('Gallery2', 1, ['Test group B', 'Test group C', 'Test group A'])
    end
  end

  scenario "View another user's list of galleries while logged in" do
    user = setup_sample_data
    login
    visit user_galleries_path(user_id: user.id)

    expect(page).to have_selector('th', text: "Test user's Galleries")
    expect(page).to have_no_selector('.gallery-new')

    within('#content tbody') do
      expect(page).to have_no_selector('.gallery-add')
      expect(page).to have_no_selector('.gallery-edit')
      expect(page).to have_no_selector('.gallery-delete')

      expect_gallery_of('[Galleryless]', 1)
      expect_gallery_of('Empty gallery', 0)
      expect_gallery_of('Gallery1', 1)
      expect_gallery_of('Gallery2', 1, ['Test group B', 'Test group C', 'Test group A'])
    end
  end

  scenario "View own list of galleries" do
    user = setup_sample_data
    login(user, 'known')
    visit user_galleries_path(user_id: user.id)

    expect(page).to have_selector('th', text: "Your Galleries")
    expect(page).to have_selector('.gallery-new')

    within('#content tbody') do
      expect(page).to have_selector('.gallery-add', count: 4)
      expect(page).to have_selector('.gallery-edit', count: 3)
      expect(page).to have_selector('.gallery-delete', count: 3)
      expect_gallery_of('[Galleryless]', 1)
      expect_gallery_of('Empty gallery', 0)
      expect_gallery_of('Gallery1', 1)
      expect_gallery_of('Gallery2', 1, ['Test group B', 'Test group C', 'Test group A'])
    end
  end
end
