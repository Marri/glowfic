require "spec_helper"

RSpec.describe ReplyScraper do
  it "should raise an error when an unexpected character is found" do
    post = Post.new(board_id: 3, subject: 'linear b', status: Post.statuses[:complete], is_import: true)

    scraper = ReplyScraper.new(post)
    expect(scraper).not_to receive(:print).with("User ID or username for wild_pegasus_appeared? ")

    scraped_info = {
      username: 'wild_pegasus_appeared',
      img_url: 'https://v.dreamwidth.org/8517100/2343677',
      img_keyword: 'sad',
      content: '',
      created_at: "Nov. 14th, 2014 04:35"
    }
    expect { scraper.import(**scraped_info) }.to raise_error(ActiveRecord::Rollback)
    expect(scraper.errors).to be_present
    expect(scraper.errors.full_messages).to include("Unrecognized username: wild_pegasus_appeared")
  end

  it "should scrape character, user and icon properly" do
    user = create(:user, username: "Marri")
    board = create(:board, creator: user)

    post = Post.new(board: board, subject: 'linear b', status: Post.statuses[:complete], is_import: true)

    scraper = ReplyScraper.new(post, console: true)
    allow(STDIN).to receive(:gets).and_return(user.username)
    expect(scraper).to receive(:print).with("User ID or username for wild_pegasus_appeared? ")

    scraped_info = {
      username: 'wild_pegasus_appeared',
      img_url: 'https://v.dreamwidth.org/8517100/2343677',
      img_keyword: 'sad',
      content: '',
      created_at: "Nov. 14th, 2014 04:35"
    }
    scraper.import(**scraped_info)

    expect(Post.count).to eq(1)
    expect(Reply.count).to eq(0)
    expect(User.count).to eq(1)
    expect(Icon.count).to eq(1)
    expect(Character.count).to eq(1)
    expect(Character.where(screenname: 'wild_pegasus_appeared').first).not_to be_nil
  end

  it "doesn't recreate characters and icons if they exist" do
    user = create(:user, username: "Marri")
    board = create(:board, creator: user)
    nita = create(:character, user: user, screenname: 'wild_pegasus_appeared', name: 'Juanita')
    icon = create(:icon, keyword: 'sad', url: 'http://v.dreamwidth.org/8517100/2343677', user: user)
    gallery = create(:gallery, user: user)
    gallery.icons << icon
    nita.galleries << gallery

    expect(User.count).to eq(1)
    expect(Icon.count).to eq(1)
    expect(Character.count).to eq(1)

    post = Post.new(board: board, subject: 'linear b', status: Post.statuses[:complete], is_import: true)

    scraper = ReplyScraper.new(post)
    expect(scraper).not_to receive(:print).with("User ID or username for wild_pegasus_appeared? ")

    scraped_info = {
      username: 'wild_pegasus_appeared',
      img_url: 'https://v.dreamwidth.org/8517100/2343677',
      img_keyword: 'sad',
      content: '',
      created_at: "Nov. 14th, 2014 04:35"
    }
    scraper.import(**scraped_info)

    expect(User.count).to eq(1)
    expect(Icon.count).to eq(1)
    expect(Character.count).to eq(1)
  end

  it "doesn't recreate icons if they already exist for that character with new urls" do
    user = create(:user, username: "Marri")
    board = create(:board, creator: user)
    nita = create(:character, user: user, screenname: 'wild_pegasus_appeared', name: 'Juanita')
    icon = create(:icon, keyword: 'sad', url: 'http://glowfic.com/uploaded/icon.png', user: user)
    gallery = create(:gallery, user: user)
    gallery.icons << icon
    nita.galleries << gallery

    expect(User.count).to eq(1)
    expect(Icon.count).to eq(1)
    expect(Character.count).to eq(1)

    post = Post.new(board: board, subject: 'linear b', status: Post.statuses[:complete], is_import: true)

    scraper = ReplyScraper.new(post)
    expect(scraper).not_to receive(:print).with("User ID or username for wild_pegasus_appeared? ")

    scraped_info = {
      username: 'wild_pegasus_appeared',
      img_url: 'https://v.dreamwidth.org/8517100/2343677',
      img_keyword: 'sad',
      content: '',
      created_at: "Nov. 14th, 2014 04:35"
    }
    scraper.import(**scraped_info)

    expect(User.count).to eq(1)
    expect(Icon.count).to eq(1)
    expect(Character.count).to eq(1)
  end

  describe "set_from_icon" do
    it "handles Kappa icons" do
      kappa = create(:user, id: 3)
      char = create(:character, user: kappa)
      gallery = create(:gallery, user: kappa)
      char.galleries << gallery
      icon = create(:icon, user: kappa, keyword: '⑮ mountains')
      gallery.icons << icon
      tag = build(:reply, user: kappa, character: char)
      scraper = ReplyScraper.new(tag)
      found_icon = scraper.send(:set_from_icon, 'http://irrelevanturl.com', 'f.1 mountains')
      expect(Icon.count).to eq(1)
      expect(found_icon.id).to eq(icon.id)
    end

    it "handles icons with descriptions" do
      user = create(:user)
      char = create(:character, user: user)
      gallery = create(:gallery, user: user)
      char.galleries << gallery
      icon = create(:icon, user: user, keyword: 'keyword blah')
      gallery.icons << icon
      tag = build(:reply, user: user, character: char)
      scraper = ReplyScraper.new(tag)
      found_icon = scraper.send(:set_from_icon, 'http://irrelevanturl.com', 'keyword blah (Accessbility description.)')
      expect(Icon.count).to eq(1)
      expect(found_icon.id).to eq(icon.id)
    end

    it "handles kappa icons with descriptions" do
      kappa = create(:user, id: 3)
      char = create(:character, user: kappa)
      gallery = create(:gallery, user: kappa)
      char.galleries << gallery
      icon = create(:icon, user: kappa, keyword: '⑮ keyword blah')
      gallery.icons << icon
      tag = build(:reply, user: kappa, character: char)
      expect(tag.icon_id).to be_nil
      scraper = ReplyScraper.new(tag)
      found_icon = scraper.send(:set_from_icon, 'http://irrelevanturl.com', 'f.1 keyword blah (Accessbility description.)')
      expect(Icon.count).to eq(1)
      expect(found_icon.id).to eq(icon.id)
    end
  end
end
