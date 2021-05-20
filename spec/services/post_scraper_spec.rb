RSpec.describe PostScraper do
  let(:url) { 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat' }

  it "should add view to url" do
    scraper = PostScraper.new('http://wild-pegasus-appeared.dreamwidth.org/403.html')
    expect(scraper.url).to include('view=flat')
  end

  it "should not change url if view is present" do
    url = 'http://wild-pegasus-appeared.dreamwidth.org/403.html?view=flat'
    scraper = PostScraper.new(url)
    expect(scraper.url.sub('view=flat', '')).not_to include('view=flat')
    expect(scraper.url.gsub("&style=site", "").length).to eq(url.length)
  end

  it "should add site style to the url" do
    url = 'http://wild-pegasus-appeared.dreamwidth.org/403.html?view=flat'
    scraper = PostScraper.new(url)
    expect(scraper.url).to include('&style=site')
  end

  it "should not change url if site style is present" do
    scraper = PostScraper.new(url)
    expect(scraper.url.length).to eq(url.length)
  end

  it "should scrape properly when nothing is created" do
    stub_fixture(url, 'scrape_single_page')
    user = create(:user, username: "Marri")
    board = create(:board, creator: user)

    scraper = PostScraper.new(url, board.id)
    allow(scraper).to receive(:prompt_for_user) { user }
    allow(scraper).to receive(:set_from_icon).and_return(nil)
    expect(scraper.send(:logger)).to receive(:info).with("Importing thread 'linear b'")

    scraper.scrape!

    expect(Post.count).to eq(1)
    expect(Reply.count).to eq(46)
    expect(User.count).to eq(1)
    expect(Icon.count).to eq(0)
    expect(Character.count).to eq(2)
    expect(Character.where(screenname: 'wild_pegasus_appeared').first).not_to be_nil
    expect(Character.where(screenname: 'undercover_talent').first).not_to be_nil
  end

  it "should scrape multiple pages" do
    url_page_2 = 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat&page=2'
    stub_fixture(url, 'scrape_multi_page')
    stub_fixture(url_page_2, 'scrape_single_page')
    user = create(:user, username: "Marri")
    board = create(:board, creator: user)

    scraper = PostScraper.new(url, board.id)
    allow(scraper).to receive(:prompt_for_user) { user }
    allow(scraper).to receive(:set_from_icon).and_return(nil)
    expect(scraper.send(:logger)).to receive(:info).with("Importing thread 'linear b'")

    scraper.scrape!

    expect(Post.count).to eq(1)
    expect(Reply.count).to eq(92)
    expect(User.count).to eq(1)
    expect(Icon.count).to eq(0)
    expect(Character.count).to eq(2)
    expect(Character.where(screenname: 'wild_pegasus_appeared').first).not_to be_nil
    expect(Character.where(screenname: 'undercover_talent').first).not_to be_nil
  end

  context "with threading" do
    it "should detect all pages" do
      url = 'http://alicornutopia.dreamwidth.org/9596.html?thread=4077436&style=site#cmt4077436'
      stub_fixture(url, 'scrape_threaded')
      scraper = setup_scraper(url)
      expect(scraper.send(:page_links).size).to eq(2)
    end

    it "should detect all pages even if there's a single broken-depth comment" do
      url = 'https://alicornutopia.dreamwidth.org/22671.html?thread=14698127&style=site#cmt14698127'
      stub_fixture(url, 'scrape_threaded_broken_depth')
      scraper = setup_scraper(url)
      expect(scraper.send(:page_links)).to eq([
        'https://alicornutopia.dreamwidth.org/22671.html?thread=14705039&style=site#cmt14705039',
        'https://alicornutopia.dreamwidth.org/22671.html?thread=14711695&style=site#cmt14711695'
      ])
    end

    it "should detect all pages even if there's a broken-depth comment at the 25-per-page boundary" do
      url = 'https://alicornutopia.dreamwidth.org/22671.html?thread=14691983#cmt14691983'
      stub_fixture(url, 'scrape_threaded_broken_boundary_depth')
      scraper = setup_scraper(url)
      expect(scraper.send(:page_links)).to eq([
        'https://alicornutopia.dreamwidth.org/22671.html?thread=14698383&style=site#cmt14698383',
        'https://alicornutopia.dreamwidth.org/22671.html?thread=14698639&style=site#cmt14698639',
        'https://alicornutopia.dreamwidth.org/22671.html?thread=14705551&style=site#cmt14705551'
      ])
    end

    def setup_scraper(url)
      scraper = PostScraper.new(url, nil, nil, nil, true)
      scraper.instance_variable_set('@html_doc', scraper.send(:doc_from_url, url))
      scraper
    end
  end

  it "should raise an error when an unexpected character is found" do
    url = 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat'
    stub_fixture(url, 'scrape_no_replies')
    scraper = PostScraper.new(url)
    expect(scraper.send(:logger)).to receive(:info).with("Importing thread 'linear b'")
    expect { scraper.scrape! }.to raise_error(UnrecognizedUsernameError)
  end

  it "should raise an error when post is already imported" do
    board = create(:board)
    create(:character, screenname: 'wild_pegasus_appeared', user: board.creator)
    url = 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat'
    stub_fixture(url, 'scrape_no_replies')
    scraper = PostScraper.new(url, board.id)
    allow(scraper.send(:logger)).to receive(:info).with("Importing thread 'linear b'")
    expect { scraper.scrape! }.to change { Post.count }.by(1)
    expect { scraper.scrape! }.to raise_error(AlreadyImportedError)
    expect(Post.count).to eq(1)
  end

  it "should raise an error when post is already imported with given subject" do
    new_title = 'other name'
    board = create(:board)
    create(:post, board: board, subject: new_title) # post
    url = 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat'
    stub_fixture(url, 'scrape_no_replies')
    scraper = PostScraper.new(url, board.id, nil, nil, false, false, new_title)
    allow(scraper.send(:logger)).to receive(:info).with("Importing thread '#{new_title}'")
    expect { scraper.scrape! }.to raise_error(AlreadyImportedError)
    expect(Post.count).to eq(1)
  end

  it "should scrape character, user and icon properly" do
    url = 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat'
    stub_fixture(url, 'scrape_no_replies')
    user = create(:user, username: "Marri")
    board = create(:board, creator: user)

    scraper = PostScraper.new(url, board.id, nil, nil, false, true)
    allow(STDIN).to receive(:gets).and_return(user.username)
    expect(scraper.send(:logger)).to receive(:info).with("Importing thread 'linear b'")
    expect(scraper).to receive(:print).with("User ID or username for wild_pegasus_appeared? ")

    scraper.scrape!

    expect(Post.count).to eq(1)
    expect(Reply.count).to eq(0)
    expect(User.count).to eq(1)
    expect(Icon.count).to eq(1)
    expect(Character.count).to eq(1)
    expect(Character.where(screenname: 'wild_pegasus_appeared').first).not_to be_nil
  end

  it "should only scrape specified threads if given" do
    stubs = {
      'https://mind-game.dreamwidth.org/1073.html?style=site'                       => 'scrape_specific_threads',
      'https://mind-game.dreamwidth.org/1073.html?thread=6961&style=site#cmt6961'   => 'scrape_specific_threads_thread1',
      'https://mind-game.dreamwidth.org/1073.html?thread=16689&style=site#cmt16689' => 'scrape_specific_threads_thread2_1',
      'https://mind-game.dreamwidth.org/1073.html?thread=48177&style=site#cmt48177' => 'scrape_specific_threads_thread2_2'
    }
    stubs.each { |url, file| stub_fixture(url, file) }
    urls = stubs.keys
    threads = urls[1..2]

    alicorn = create(:user, username: 'Alicorn')
    kappa = create(:user, username: 'Kappa')
    board = create(:board, creator: alicorn, writers: [kappa])
    characters = [
      {screenname: 'mind_game', name: 'Jane', user: alicorn},
      {screenname: 'luminous_regnant', name: 'Isabella Marie Swan Cullen ☼ "Golden"', user: alicorn},
      {screenname: 'manofmyword', name: 'here\'s my card', user: kappa},
      {screenname: 'temporal_affairs', name: 'Nathan Corlett | Minister of Temporal Affairs', user: alicorn},
      {screenname: 'pina_colada', name: 'Kerron Corlett', user: alicorn},
      {screenname: 'pumpkin_pie', name: 'Aedyt Corlett', user: kappa},
      {screenname: 'lifes_sake', name: 'Campbell Mark Swan ҂ "Cam"', user: alicorn},
      {screenname: 'withmypowers', name: 'Matilda Wormwood Honey', user: kappa}
    ]
    characters.each { |data| create(:character, data) }

    scraper = PostScraper.new(urls.first, board.id, nil, nil, true, false)
    expect(scraper.send(:logger)).to receive(:info).with("Importing thread 'repealing'")
    scraper.scrape_threads!(threads)
    expect(Post.count).to eq(1)
    expect(Post.first.subject).to eq('repealing')
    expect(Post.first.authors_locked).to eq(true)
    expect(Reply.count).to eq(55)
    expect(User.count).to eq(2)
    expect(Icon.count).to eq(30)
    expect(Character.count).to eq(8)
  end

  context "with icons" do
    let(:user) { create(:user, username: "Marri") }
    let(:board) { create(:board, creator: user) }
    let(:icon) { create(:icon, keyword: 'sad', url: 'http://v.dreamwidth.org/8517100/2343677', user: user) }
    let(:url) { 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat' }
    let(:scraper) { PostScraper.new(url, board.id) }

    before(:each) do
      gallery = create(:gallery, user: user, icons: [icon])
      create(:character, user: user, screenname: 'wild_pegasus_appeared', name: 'Juanita', galleries: [gallery])
      stub_fixture(url, 'scrape_no_replies')
    end

    it "doesn't recreate characters and icons if they exist" do
      expect(scraper).not_to receive(:print).with("User ID or username for wild_pegasus_appeared? ")
      expect(scraper.send(:logger)).to receive(:info).with("Importing thread 'linear b'") # just to quiet it

      expect { scraper.scrape! }.to not_change{User.count}.and not_change{Icon.count}.and not_change{Character.count}
    end

    it "doesn't recreate icons if they already exist for that character with new urls" do
      icon.update!(url: 'http://glowfic.com/uploaded/icon.png')

      expect(scraper).not_to receive(:print).with("User ID or username for wild_pegasus_appeared? ")
      expect(scraper.send(:logger)).to receive(:info).with("Importing thread 'linear b'") # just to quiet it

      expect { scraper.scrape! }.to not_change{User.count}.and not_change{Icon.count}.and not_change{Character.count}
    end
  end

  describe "#set_from_icon" do
    let(:user) { create(:user) }
    let(:gallery) { create(:gallery, user: user) }
    let(:char) { create(:character, user: user, galleries: [gallery]) }
    let(:tag) { build(:reply, user: user, character: char) }
    let(:scraper) { PostScraper.new('') }

    it "handles icons with descriptions" do
      icon = create(:icon, user: user, keyword: 'keyword blah')
      gallery.icons << icon
      expect(tag.icon_id).to be_nil

      scraper.send(:set_from_icon, tag, 'http://irrelevanturl.com', 'keyword blah (Accessbility description.)')
      expect(Icon.count).to eq(1)
      expect(tag.icon_id).to eq(icon.id)
    end

    context "with kappa icons" do
      let(:user) { create(:user, id: 3) }

      it "works" do
        icon = create(:icon, user: user, keyword: '⑮ mountains')
        gallery.icons << icon
        expect(tag.icon_id).to be_nil

        scraper.send(:set_from_icon, tag, 'http://irrelevanturl.com', 'f.1 mountains')
        expect(Icon.count).to eq(1)
        expect(tag.icon_id).to eq(icon.id)
      end

      it "works with descriptions" do
        icon = create(:icon, user: user, keyword: '⑮ keyword blah')
        gallery.icons << icon
        expect(tag.icon_id).to be_nil

        scraper.send(:set_from_icon, tag, 'http://irrelevanturl.com', 'f.1 keyword blah (Accessbility description.)')
        expect(Icon.count).to eq(1)
        expect(tag.icon_id).to eq(icon.id)
      end
    end
  end

  it "can fail a download" do
    url = 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat'
    scraper = PostScraper.new(url)

    expect(HTTParty).to receive(:get).with(url).exactly(3).times.and_raise(Net::OpenTimeout, 'example failure')

    expect {
      scraper.send(:doc_from_url, url)
    }.to raise_error(Net::OpenTimeout, 'example failure')
  end

  it "handles retrying of downloads" do
    url = 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat'
    scraper = PostScraper.new(url)

    html = "<!DOCTYPE html>\n<html></html>\n"
    stub_with_body = double
    expect(stub_with_body).to receive(:body).and_return(html)

    allow(HTTParty).to receive(:get).with(url).once.and_raise(Net::OpenTimeout, 'example failure')
    allow(HTTParty).to receive(:get).with(url).and_return(stub_with_body)

    expect(scraper.send(:doc_from_url, url).to_s).to eq(html)
  end
end
