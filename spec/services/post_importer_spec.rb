RSpec.describe PostImporter do
  include ActiveJob::TestHelper

  describe "import" do
    let(:url) { 'http://wild-pegasus-appeared.dreamwidth.org/403.html?style=site&view=flat' }

    before(:each) { clear_enqueued_jobs }

    context "when validating url" do
      it "raises error on nil url" do
        importer = PostImporter.new(nil)
        expect { importer.import(nil, nil) }.to raise_error(InvalidDreamwidthURL)
        expect(ScrapePostJob).not_to have_been_enqueued
      end

      it "raises error on empty url" do
        importer = PostImporter.new('')
        expect { importer.import(nil, nil) }.to raise_error(InvalidDreamwidthURL)
        expect(ScrapePostJob).not_to have_been_enqueued
      end

      it "raises error without dreamwidth url" do
        importer = PostImporter.new('http://www.google.com')
        expect { importer.import(nil, nil) }.to raise_error(InvalidDreamwidthURL)
        expect(ScrapePostJob).not_to have_been_enqueued
      end

      it "raises error without dreamwidth.org url" do
        importer = PostImporter.new('http://www.dreamwidth.com')
        expect { importer.import(nil, nil) }.to raise_error(InvalidDreamwidthURL)
        expect(ScrapePostJob).not_to have_been_enqueued
      end

      it "raises error on malformed url" do
        importer = PostImporter.new('http://localhostdreamwidth:3000index')
        expect { importer.import(nil, nil) }.to raise_error(InvalidDreamwidthURL)
        expect(ScrapePostJob).not_to have_been_enqueued
      end
    end

    context "when validating duplicate imports" do
      let(:post) { create(:post, subject: 'linear b') }
      let(:importer) { PostImporter.new(url) }

      before(:each) do
        stub_fixture(url, 'scrape_no_replies')
        create(:character, screenname: 'wild_pegasus_appeared', user: post.user)
      end

      it "does not raise error on threaded imports" do
        expect { importer.import(post.board_id, nil, threaded: true) }.not_to raise_error
        expect(ScrapePostJob).to have_been_enqueued
      end

      it "does not raise error on different continuity imports" do
        expect { importer.import(post.board_id + 1, nil) }.not_to raise_error
        expect(ScrapePostJob).to have_been_enqueued
      end

      it "raises error on duplicate" do
        expect { importer.import(post.board_id, nil) }.to raise_error(AlreadyImported)
        expect(ScrapePostJob).not_to have_been_enqueued
      end
    end

    context "when validating duplicate usernames" do
      let(:importer) { PostImporter.new(url) }

      before(:each) { stub_fixture(url, 'scrape_no_replies') }

      it "requires usernames to exist" do
        expect { importer.import(nil, nil) }.to raise_error(MissingUsernames)
        expect(ScrapePostJob).not_to have_been_enqueued
      end

      it "handles usernames with - instead of _" do
        create(:character, screenname: 'wild-pegasus-appeared')
        expect { importer.import(nil, nil) }.not_to raise_error
        expect(ScrapePostJob).to have_been_enqueued
      end
    end

    it "should enqueue a job on success" do
      create(:character, screenname: 'wild_pegasus_appeared')
      stub_fixture(url, 'scrape_no_replies')
      importer = PostImporter.new(url)
      expect { importer.import(5, 2, section_id: 3, status: 1, threaded: true) }.not_to raise_error
      expect(ScrapePostJob).to have_been_enqueued.with(url, 5, 3, 1, true, 2).on_queue('low')
    end
  end
end
