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

  context "associations" do
    it "tracks parents and children" do
      parent1 = create(:setting) # has child1, child2, and child3 as children
      parent2 = create(:setting) # has child2 as child
      child1 = create(:setting) # has parent1 as parent and child2 as child
      child2 = create(:setting) # has parent1, parent2, and child1 as parents
      child3 = create(:setting) # has parent1 as parent

      child1.parent_setting_list = [parent1.name]
      child1.save!

      child2.update!(parent_setting_list: [parent1, parent2, child1].map(&:name))
      child3.update!(parent_setting_list: [parent1.name])

      expect(parent1.reload.child_settings.ids).to match_array([child1, child2, child3].map(&:id))
      expect(parent2.child_settings.ids).to eq([child2.id])
      expect(child1.child_settings.ids).to eq([child2.id])

      expect(child1.parent_settings.ids).to eq([parent1.id])
      expect(child2.parent_settings.ids).to match_array([parent1, parent2, child1].map(&:id))
      expect(child3.parent_settings.ids).to eq([parent1.id])
    end
  end
end
