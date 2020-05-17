RSpec.describe PostImporter do
  include ActiveJob::TestHelper

  describe "import" do
    let(:url) { 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat' }

    before(:each) { clear_enqueued_jobs }

    context "when validating url" do
      it "raises error on nil url" do
        importer = PostImporter.new(nil)
        importer.import({}, user: nil)
        expect(importer.errors).to be_present
        expect(importer.errors.full_messages.first).to eq('Url is invalid')
        expect(ScrapePostJob).not_to have_been_enqueued
      end

      it "raises error on empty url" do
        importer = PostImporter.new('')
        importer.import({}, user: nil)
        expect(importer.errors).to be_present
        expect(importer.errors.full_messages.first).to eq('Url is invalid')
        expect(ScrapePostJob).not_to have_been_enqueued
      end

      it "raises error without dreamwidth url" do
        importer = PostImporter.new('http://www.google.com')
        importer.import({}, user: nil)
        expect(importer.errors).to be_present
        expect(importer.errors.full_messages.first).to eq('Url is invalid')
        expect(ScrapePostJob).not_to have_been_enqueued
      end

      it "raises error without dreamwidth.org url" do
        importer = PostImporter.new('http://www.dreamwidth.com')
        importer.import({}, user: nil)
        expect(importer.errors).to be_present
        expect(importer.errors.full_messages.first).to eq('Url is invalid')
        expect(ScrapePostJob).not_to have_been_enqueued
      end

      it "raises error on malformed url" do
        importer = PostImporter.new('http://localhostdreamwidth:3000index')
        importer.import({}, user: nil)
        expect(importer.errors).to be_present
        expect(importer.errors.full_messages.first).to eq('Url is invalid')
        expect(ScrapePostJob).not_to have_been_enqueued
      end
    end

    context "when validating duplicate imports" do
      let(:post) { create(:post, subject: 'linear b') }

      before(:each) do
        stub_fixture(url, 'scrape_no_replies')
        create(:character, screenname: 'wild_pegasus_appeared', user: post.user)
      end

      it "does not raise error on threaded imports" do
        importer = PostImporter.new(url)
        params = { board_id: post.board_id, threaded: true }
        importer.import(params, user: nil)
        expect(importer.errors).not_to be_present
        expect(ScrapePostJob).to have_been_enqueued
      end

      it "does not raise error on different continuity imports" do
        importer = PostImporter.new(url)
        params = { board_id: post.board_id + 1 }
        importer.import(params, user: nil)
        expect(importer.errors).not_to be_present
        expect(ScrapePostJob).to have_been_enqueued
      end

      it "raises error on duplicate" do
        importer = PostImporter.new(url)
        params = { board_id: post.board_id }
        importer.import(params, user: nil)
        expect(importer.errors).to be_present
        expect(importer.errors.full_messages.first).to start_with('Post has already been imported!')
        expect(ScrapePostJob).not_to have_been_enqueued
      end
    end

    context "when validating duplicate usernames" do
      it "requires usernames to exist" do
        stub_fixture(url, 'scrape_no_replies')
        importer = PostImporter.new(url)
        importer.import({}, user: nil)
        expect(importer.errors).to be_present
        expect(importer.errors.full_messages.first).to start_with('The following usernames were not recognized.')
        expect(ScrapePostJob).not_to have_been_enqueued
      end

      it "handles usernames with - instead of _" do
        create(:character, screenname: 'wild-pegasus-appeared')
        stub_fixture(url, 'scrape_no_replies')
        importer = PostImporter.new(url)
        importer.import({}, user: nil)
        expect(importer.errors).not_to be_present
        expect(ScrapePostJob).to have_been_enqueued
      end
    end

    it "should enqueue a job on success" do
      create(:character, screenname: 'wild_pegasus_appeared')
      stub_fixture(url, 'scrape_no_replies')
      importer = PostImporter.new(url)
      params = { board_id: 5, section_id: 3, status: 1, threaded: true }
      user = User.find_by(id: 2)
      importer.import(params, user: user)
      expect(importer.errors).not_to be_present
      expect(ScrapePostJob).to have_been_enqueued.with(params, user: user).on_queue('low')
    end
  end
end
