require "spec_helper"

RSpec.describe ReplyScraper do
  let(:user) { create(:user, username: "Marri") }
  let(:board) { create(:board, creator: user) }
  let(:post) { Post.new(board: board, subject: 'linear b', status: Post.statuses[:complete], is_import: true) }

  let(:doc) do
    url = 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat'
    stub_fixture(url, 'scrape_no_replies')
    PostScraper.new(url).send(:doc_from_url, url)
  end

  it "should raise an error when an unexpected character is found" do
    scraper = ReplyScraper.new(post)
    expect(scraper).not_to receive(:print).with("User ID or username for wild_pegasus_appeared? ")
    expect { scraper.import(doc) }.to raise_error(UnrecognizedUsernameError)
  end

  it "should scrape character, user and icon properly" do
    scraper = ReplyScraper.new(post, console: true)
    allow(STDIN).to receive(:gets).and_return(user.username)
    expect(scraper).to receive(:print).with("User ID or username for wild_pegasus_appeared? ")
    scraper.import(doc)

    expect(Post.count).to eq(1)
    expect(Reply.count).to eq(0)
    expect(User.count).to eq(1)
    expect(Icon.count).to eq(1)
    expect(Character.count).to eq(1)
    expect(Character.where(screenname: 'wild_pegasus_appeared').first).not_to be_nil
  end

  it "doesn't recreate characters and icons if they exist" do
    nita = create(:character, user: user, screenname: 'wild_pegasus_appeared', name: 'Juanita')
    icon = create(:icon, keyword: 'sad', url: 'http://v.dreamwidth.org/8517100/2343677', user: user)
    gallery = create(:gallery, user: user)
    gallery.icons << icon
    nita.galleries << gallery

    expect(User.count).to eq(1)
    expect(Icon.count).to eq(1)
    expect(Character.count).to eq(1)

    scraper = ReplyScraper.new(post)
    expect(scraper).not_to receive(:print).with("User ID or username for wild_pegasus_appeared? ")
    scraper.import(doc)

    expect(User.count).to eq(1)
    expect(Icon.count).to eq(1)
    expect(Character.count).to eq(1)
  end

  it "doesn't recreate icons if they already exist for that character with new urls" do
    nita = create(:character, user: user, screenname: 'wild_pegasus_appeared', name: 'Juanita')
    icon = create(:icon, keyword: 'sad', url: 'http://glowfic.com/uploaded/icon.png', user: user)
    gallery = create(:gallery, user: user)
    gallery.icons << icon
    nita.galleries << gallery

    expect(User.count).to eq(1)
    expect(Icon.count).to eq(1)
    expect(Character.count).to eq(1)

    scraper = ReplyScraper.new(post)
    expect(scraper).not_to receive(:print).with("User ID or username for wild_pegasus_appeared? ")
    scraper.import(doc)

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
      expect(tag.icon_id).to be_nil
      scraper = ReplyScraper.new(tag)
      scraper.send(:set_from_icon, tag, 'http://irrelevanturl.com', 'f.1 mountains')
      expect(Icon.count).to eq(1)
      expect(tag.icon_id).to eq(icon.id)
    end

    it "handles icons with descriptions" do
      user = create(:user)
      char = create(:character, user: user)
      gallery = create(:gallery, user: user)
      char.galleries << gallery
      icon = create(:icon, user: user, keyword: 'keyword blah')
      gallery.icons << icon
      tag = build(:reply, user: user, character: char)
      expect(tag.icon_id).to be_nil
      scraper = ReplyScraper.new(tag)
      scraper.send(:set_from_icon, tag, 'http://irrelevanturl.com', 'keyword blah (Accessbility description.)')
      expect(Icon.count).to eq(1)
      expect(tag.icon_id).to eq(icon.id)
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
      scraper.send(:set_from_icon, tag, 'http://irrelevanturl.com', 'f.1 keyword blah (Accessbility description.)')
      expect(Icon.count).to eq(1)
      expect(tag.icon_id).to eq(icon.id)
    end
  end
end
