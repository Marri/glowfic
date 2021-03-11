RSpec.describe Setting do
  context "tags" do
    it "creates only in-memory tags on invalid create" do
      harry_potter = create(:setting, name: 'Harry Potter')
      setting = build(:setting, name: '', parent_settings: [harry_potter])
      expect(setting.valid?).to eq(false)
      expect(setting.save).to eq(false)
      expect(setting.parent_settings.count).to eq(0)
      expect(setting.parent_settings.size).to eq(1)
      expect(Tag::SettingTag.count).to eq(0)
    end

    it "creates tags on valid create" do
      harry_potter = create(:setting, name: 'Harry Potter')
      setting = build(:setting, parent_settings: [harry_potter])
      expect(setting.valid?).to eq(true)
      expect(setting.save).to eq(true)
      expect(setting.parent_settings.count).to eq(1)
      expect(setting.parent_settings.size).to eq(1)
      expect(Tag::SettingTag.count).to eq(1)
    end
  end
end
