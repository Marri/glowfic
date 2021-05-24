RSpec.describe Setting do
  describe "validations" do
    it "requires unique name" do
      tag = create(:setting)
      new_tag = build(:setting, name: tag.name)
      expect(new_tag).not_to be_valid
    end

    it "requires unique case sensitive name" do
      tag = create(:setting, name: 'CASE')
      new_tag = build(:setting, name: tag.name.downcase)
      expect(new_tag).not_to be_valid
    end
  end

  context "tags" do
    it "creates only in-memory tags on invalid create" do
      harry_potter = create(:setting, name: 'Harry Potter')
      setting = build(:setting, name: '', parent_settings: [harry_potter])
      expect(setting.valid?).to eq(false)
      expect(setting.save).to eq(false)
      expect(setting.parent_settings.count).to eq(0)
      expect(setting.parent_settings.size).to eq(1)
      expect(Setting::SettingTag.count).to eq(0)
    end

    it "creates tags on valid create" do
      harry_potter = create(:setting, name: 'Harry Potter')
      setting = build(:setting, parent_settings: [harry_potter])
      expect(setting.valid?).to eq(true)
      expect(setting.save).to eq(true)
      expect(setting.parent_settings.count).to eq(1)
      expect(setting.parent_settings.size).to eq(1)
      expect(Setting::SettingTag.count).to eq(1)
    end
  end

  describe "#id_for_select" do
    it "uses ID if persisted" do
      tag = create(:setting)
      expect(tag.id_for_select).to eq(tag.id)
    end

    it "uses name with prepended underscore otherwise" do
      tag = build(:setting, name: 'tag')
      expect(tag.id_for_select).to eq('_tag')
    end
  end

  describe "#post_count" do
    it "works" do
      tag1 = create(:setting)
      tag2 = create(:setting)
      create(:post, settings: [tag2])
      tag3 = create(:setting)
      create_list(:post, 2, settings: [tag3])
      tags = [tag1, tag2, tag3]
      fetched = Setting.where(id: tags.map(&:id)).ordered_by_id
      expect(fetched).to eq(tags)
      expect(fetched.map(&:post_count)).to eq([0, 1, 2])
    end
  end

  describe "#character_count" do
    def create_tags
      tag1 = create(:setting)
      tag2 = create(:setting)
      create(:character, settings: [tag2])
      tag3 = create(:setting)
      create_list(:character, 2, settings: [tag3])
      [tag1, tag2, tag3]
    end

    it "works with with_character_counts scope" do
      tags = create_tags
      fetched = Setting.where(id: tags.map(&:id)).select(:id).ordered_by_id.with_character_counts
      expect(fetched).to eq(tags)
      expect(fetched.map{|x| x[:character_count] }).to eq([0, 1, 2])
    end

    it "works without with_character_counts scope" do
      tags = create_tags
      fetched = Setting.where(id: tags.map(&:id)).ordered_by_id
      expect(fetched).to eq(tags)
      expect(fetched.map(&:character_count)).to eq([0, 1, 2])
    end
  end
end
