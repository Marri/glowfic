require "spec_helper"

RSpec.describe Icon do
  include ActiveJob::TestHelper

  describe "#validations" do
    it "requires url" do
      icon = build(:icon, url: nil)
      expect(icon).not_to be_valid
      icon = build(:icon, url: '')
      expect(icon).not_to be_valid
    end

    it "requires url-looking url" do
      icon = build(:icon, url: 'not-a-url')
      expect(icon).not_to be_valid
    end

    it "requires user" do
      icon = build(:icon, user: nil)
      expect(icon).not_to be_valid
    end

    it "requires keyword" do
      icon = build(:icon, keyword: nil)
      expect(icon).not_to be_valid
      icon = build(:icon, keyword: '')
      expect(icon).not_to be_valid
    end

    context "#uploaded_url_not_in_use" do
      it "should set the url back to its previous url on create" do
        icon = create(:old_uploaded_icon)
        dupe_icon = build(:icon, url: icon.url, s3_key: icon.s3_key)
        expect(dupe_icon).not_to be_valid
        expect(dupe_icon.url).to be nil
      end

      it "should set the url back to its previous url on update" do
        icon = create(:old_uploaded_icon)
        dupe_icon = create(:icon)
        old_url = dupe_icon.url
        dupe_icon.url = icon.url
        dupe_icon.s3_key = icon.s3_key
        expect(dupe_icon.save).to be false
        expect(dupe_icon.url).to eq(old_url)
      end
    end
  end

  describe "#after_destroy" do
    it "updates reply ids" do
      reply = create(:reply, with_icon: true)
      perform_enqueued_jobs(only: UpdateModelJob) do
        reply.icon.destroy
      end
      reply.reload
      expect(reply.icon_id).to be_nil
    end

    it "updates avatar ids" do
      icon = create(:icon)
      icon.user.avatar = icon
      icon.user.save!
      icon.destroy!
      expect(icon.user.reload.avatar_id).to be_nil
    end
  end

  describe "#use_https" do
    it "does not update sites that might not support HTTPS" do
      icon = build(:icon, url: 'http://www.example.com')
      icon.save!
      expect(icon.reload.url).to start_with('http:')
    end

    it "does update HTTP Dreamwidth icons on update" do
      icon = create(:icon, url: 'http://www.example.com')
      expect(icon.reload.url).to start_with('http:')
      icon.url = 'http://www.dreamwidth.org'
      icon.save!
      expect(icon.reload.url).to start_with('https:')
    end

    it "does update HTTP Imgur icons on create" do
      icon = build(:icon, url: 'http://i.imgur.com')
      icon.save!
      expect(icon.reload.url).to start_with('https:')
    end
  end

  describe "#delete_from_s3" do
    before(:each) { clear_enqueued_jobs }

    it "deletes uploaded on destroy" do
      icon = create(:old_uploaded_icon)
      icon.destroy!
      expect(DeleteIconFromS3Job).to have_been_enqueued.with(icon.s3_key).on_queue('high')
    end

    it "does not delete non-uploaded on destroy" do
      icon = create(:icon)
      icon.destroy!
      expect(DeleteIconFromS3Job).not_to have_been_enqueued
      expect(ActiveStorage::PurgeJob).not_to have_been_enqueued
    end

    it "deletes uploaded on new uploaded update" do
      icon = create(:old_uploaded_icon)
      old_key = icon.s3_key
      icon.url = "https://d1anwqy6ci9o1i.cloudfront.net/users/#{icon.user.id}/icons/nonsense-fakeimg2.png"
      icon.s3_key = "/users/#{icon.user.id}/icons/nonsense-fakeimg2.png"
      icon.save!
      expect(DeleteIconFromS3Job).to have_been_enqueued.with(old_key).on_queue('high')
    end

    it "deletes uploaded on new non-uploaded update" do
      icon = create(:old_uploaded_icon)
      old_key = icon.s3_key
      icon.url = "https://fake.com/nonsense-fakeimg2.png"
      icon.s3_key = "/users/#{icon.user.id}/icons/nonsense-fakeimg2.png"
      icon.save!
      expect(DeleteIconFromS3Job).to have_been_enqueued.with(old_key).on_queue('high')
    end

    it "does not delete uploaded on non-url update" do
      icon = create(:old_uploaded_icon)
      icon.keyword = "not a url update"
      icon.save!
      expect(DeleteIconFromS3Job).not_to have_been_enqueued
    end
  end

  describe "#delete_from_storage" do
    before(:each) { clear_enqueued_jobs }

    it "deletes uploaded on destroy" do
      icon = create(:uploaded_icon)
      icon.destroy!
      blob = ActiveStorage::Blob.first
      expect(ActiveStorage::PurgeJob).to have_been_enqueued.with(blob).on_queue('default')
      expect(DeleteIconFromS3Job).not_to have_been_enqueued
    end

    it "deletes uploaded on new uploaded update" do
      icon = create(:uploaded_icon)
      blob = ActiveStorage::Blob.first
      icon.update!(image: fixture_file_upload(Rails.root.join('app', 'assets', 'images', 'icons', 'accept.png'), 'image/png'))
      expect(ActiveStorage::PurgeJob).to have_been_enqueued.with(blob).on_queue('default')
    end

    it "does not delete uploaded on non-url update" do
      icon = create(:uploaded_icon)
      icon.keyword = "not a url update"
      icon.save!
      expect(ActiveStorage::PurgeJob).not_to have_been_enqueued
    end
  end
end
