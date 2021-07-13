RSpec.describe News do
  let(:news) { create(:news) }
  let(:user) { create(:user) }

  describe "#mark_read" do
    it "works for never reads" do
      expect(NewsView.count).to eq(0)
      news.mark_read(news.user)
      expect(NewsView.count).to eq(1)
      expect(NewsView.last.news).to eq(news)
    end

    it "works for subsequent reads" do
      news.mark_read(news.user)
      view = NewsView.last
      new_news = create(:news)
      new_news.mark_read(news.user)
      expect(view.reload.news).to eq(new_news)
    end

    it "does nothing for historical reads" do
      news
      new_news = create(:news)
      new_news.mark_read(news.user)
      expect(NewsView.last.news).to eq(new_news)
      news.mark_read(news.user)
      expect(NewsView.last.news).to eq(new_news)
    end
  end

  describe "#num_unread_for" do
    before(:each) { news }

    it "handles no user" do
      expect(News.num_unread_for(nil)).to eq(0)
    end

    it "returns correct number for partially read" do
      news.mark_read(user)
      create_list(:news, 5)
      expect(News.num_unread_for(user)).to eq(5)
    end

    it "returns correct number for unread" do
      create_list(:news, 5)
      expect(News.num_unread_for(user)).to eq(6)
    end

    context "caching" do
      it "creates cache when num_unread_for is called" do
        expect(Rails.cache.exist?(NewsView.cache_string_for(user.id))).to eq(false)
        expect(News.num_unread_for(user)).to eq(1)
        expect(Rails.cache.exist?(NewsView.cache_string_for(user.id))).to eq(true)
      end

      it "deletes cache when NewsView is created" do
        expect(NewsView.count).to eq(0)
        news.mark_read(user)
        expect(Rails.cache.exist?(NewsView.cache_string_for(user.id))).to eq(false)
      end

      it "deletes cache when NewsView is updated" do
        news.mark_read(user)
        expect(NewsView.count).to eq(1)
        create(:news)
        News.num_unread_for(user)
        expect(Rails.cache.exist?(NewsView.cache_string_for(user.id))).to eq(true)
        news.mark_read(user)
        expect(Rails.cache.exist?(NewsView.cache_string_for(user.id))).to eq(false)
      end

      it "deletes cache when News is created" do
        expect(News.num_unread_for(user)).to eq(1)
        expect(Rails.cache.exist?(NewsView.cache_string_for(user.id))).to eq(true)
        create(:news)
        expect(Rails.cache.exist?(NewsView.cache_string_for(user.id))).to eq(false)
      end
    end
  end

  describe "#editable_by?" do
    it "requires login" do
      expect(news.editable_by?(nil)).to eq(false)
    end

    it "returns true for creator" do
      expect(news.editable_by?(news.user)).to eq(true)
    end

    it "returns true for admin" do
      admin = create(:admin_user)
      expect(news.editable_by?(admin)).to eq(true)
    end

    it "returns false for other user" do
      expect(news.editable_by?(user)).to eq(false)
    end
  end

  describe "#deletable_by?" do
    it "requires login" do
      expect(news.deletable_by?(nil)).to eq(false)
    end

    it "returns true for creator" do
      expect(news.deletable_by?(news.user)).to eq(true)
    end

    it "returns true for admin" do
      admin = create(:admin_user)
      expect(news.deletable_by?(admin)).to eq(true)
    end

    it "returns false for other user" do
      expect(news.deletable_by?(user)).to eq(false)
    end
  end
end
