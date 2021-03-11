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

    describe "#uploaded_url_yours" do
      it "should set the url back to its previous url on create" do
        icon = create(:uploaded_icon)
        dupe_icon = build(:icon, url: icon.url, s3_key: icon.s3_key, user: create(:user))
        expect(dupe_icon).not_to be_valid
        expect(dupe_icon.url).to be nil
      end

      it "should set the url back to its previous url on update" do
        icon = create(:uploaded_icon)
        dupe_icon = create(:icon)
        old_url = dupe_icon.url
        dupe_icon.url = icon.url
        dupe_icon.s3_key = icon.s3_key
        dupe_icon.user_id = create(:user)
        expect(dupe_icon.save).to be false
        expect(dupe_icon.url).to eq(old_url)
      end

      it "does not allow url/s3_key mismatch" do
        icon = build(:icon, user: create(:user))
        icon.url = "https://d1anwqy6ci9o1i.cloudfront.net/users%2F#{icon.user.id}%2Ficons%2Fnonsense-fakeimg2.png"
        icon.s3_key = "users/#{icon.user.id + 1}/icons/nonsense-fakeimg2.png"
        expect(icon.save).to be false
        expect(icon.url).to be_nil
      end
    end
  end

  describe "#after_destroy" do
    it "updates reply ids" do
      reply = create(:reply, with_icon: true)
      perform_enqueued_jobs(only: UpdateModelJob) do
        Audited.audit_class.as_user(reply.user) { reply.icon.destroy! }
      end
      reply.reload
      expect(reply.icon_id).to be_nil
    end

    it "updates avatar ids" do
      icon = create(:icon)
      icon.user.avatar = icon
      icon.user.save!
      Audited.audit_class.as_user(icon.user) { icon.destroy! }
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
      icon = create(:uploaded_icon)
      Audited.audit_class.as_user(icon.user) { icon.destroy! }
      expect(DeleteIconFromS3Job).to have_been_enqueued.with(icon.s3_key).on_queue('high')
    end

    it "does not delete non-uploaded on destroy" do
      icon = create(:icon)
      Audited.audit_class.as_user(icon.user) { icon.destroy! }
      expect(DeleteIconFromS3Job).not_to have_been_enqueued
    end

    it "deletes uploaded on new uploaded update" do
      icon = create(:uploaded_icon)
      old_key = icon.s3_key
      icon.url = "https://d1anwqy6ci9o1i.cloudfront.net/users%2F#{icon.user.id}%2Ficons%2Fnonsense-fakeimg2.png"
      icon.s3_key = "users/#{icon.user.id}/icons/nonsense-fakeimg2.png"
      icon.save!
      expect(DeleteIconFromS3Job).to have_been_enqueued.with(old_key).on_queue('high')
    end

    it "does not delete uploaded on non-url update" do
      icon = create(:uploaded_icon)
      icon.keyword = "not a url update"
      icon.save!
      expect(DeleteIconFromS3Job).not_to have_been_enqueued
    end
  end

  describe "#use_icon_host" do
    let(:asset_host) { "https://fake.cloudfront.net" }

    before(:each) { @cached_host = ENV['ICON_HOST'] }

    after(:each) { ENV['ICON_HOST'] = @cached_host }

    it "does nothing unless asset host is present" do
      ENV['ICON_HOST'] = nil
      icon = build(:icon, user: create(:user))
      url = "https://glowfic-bucket.s3.amazonaws.com/users%2F#{icon.user.id}%2Ficons%2Ffake_test.png"
      icon.s3_key = "users/#{icon.user_id}/icons/fake_test.png"
      icon.url = url
      icon.save!
      expect(icon.reload.url).to eq(url)
    end

    it "does nothing unless the icon is uploaded" do
      ENV['ICON_HOST'] = asset_host
      icon = build(:icon, user: create(:user))
      url = "https://glowfic-bucket.s3.amazonaws.com/users%2F#{icon.user.id}%2Ficons%2Ffake_test.png"
      icon.s3_key = nil
      icon.url = url
      icon.save!
      expect(icon.reload.url).to eq(url)
    end

    it "does nothing unless the icon already has the asset host domain in it" do
      ENV['ICON_HOST'] = asset_host
      icon = build(:icon, user: create(:user))
      url = "#{asset_host}/users%2F#{icon.user_id}%2Ficons%2Ffake_test.png"
      icon.s3_key = "users/#{icon.user_id}/icons/fake_test.png"
      icon.url = url
      icon.save!
      expect(icon.reload.url).to eq(url)
    end

    it "handles weird URL-less AWS edge case" do
      ENV['ICON_HOST'] = asset_host
      icon = build(:uploaded_icon, url: '')
      expect(icon.save).to eq(false)
    end

    it "updates the s3 domain to the asset host domain" do
      ENV['ICON_HOST'] = asset_host
      icon = build(:icon, user: create(:user))
      icon.url = "https://glowfic-bucket.s3.amazonaws.com/users%2F#{icon.user_id}%2Ficons%2Ffake_test.png"
      icon.s3_key = "users/#{icon.user_id}/icons/fake_test.png"
      icon.save!
      expect(icon.reload.url).to eq("#{asset_host}/users%2F#{icon.user_id}%2Ficons%2Ffake_test.png")
    end
  end
end
