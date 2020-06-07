RSpec.describe Tag do
  describe "#merge_with" do
    it "declines to merge tags of different types" do
      expect(create(:setting).merge_with(create(:label))).to eq(false)
    end

    it "correctly merges labels" do
      good_tag = create(:label)
      bad_tag = create(:label)

      # TODO handle properly with nested attributes
      create_list(:post, 3, labels: [good_tag])
      create_list(:post, 2, labels: [bad_tag])
      mutual = create(:post, labels: [good_tag, bad_tag])

      expect(good_tag.posts.count).to eq(4)
      expect(bad_tag.posts.count).to eq(3)

      good_tag.merge_with(bad_tag)

      expect(Tag.find_by_id(bad_tag.id)).to be_nil
      expect(bad_tag.posts.count).to eq(0)
      expect(good_tag.posts.count).to eq(6)
      expect(mutual.labels.count).to eq(1)
    end

    it "correctly merges settings" do
      good_setting = create(:setting)
      bad_setting = create(:setting)

      create(:setting, parent_settings: [good_setting])
      create(:setting, parent_settings: [bad_setting])
      mutual_child = create(:setting, parent_settings: [good_setting, bad_setting])

      good_parent = create(:setting)
      bad_parent = create(:setting)
      mutual_parent = create(:setting)
      good_setting.update!(parent_settings: [good_parent, mutual_parent])
      bad_setting.update!(parent_settings: [bad_parent, mutual_parent])

      create(:character, settings: [good_setting])
      create(:character, settings: [bad_setting])

      create(:post, settings: [good_setting])
      create(:post, settings: [bad_setting])

      expect(good_setting.reload.parent_settings.count).to eq(2)
      expect(good_setting.reload.child_settings.count).to eq(2)
      expect(good_setting.characters.count).to eq(1)
      expect(good_setting.posts.count).to eq(1)
      expect(bad_setting.reload.parent_settings.count).to eq(2)
      expect(bad_setting.reload.child_settings.count).to eq(2)
      expect(bad_setting.characters.count).to eq(1)
      expect(bad_setting.posts.count).to eq(1)

      good_setting.merge_with(bad_setting)

      good_setting.reload

      expect(Tag.find_by(id: bad_setting.id)).to be_nil
      expect(good_setting.child_settings.count).to eq(3)
      expect(good_setting.characters.count).to eq(2)
      expect(good_setting.posts.count).to eq(2)
      expect(good_setting.parent_settings.count).to eq(3)
      expect(mutual_child.parent_settings.count).to eq(1)
      expect(mutual_parent.child_settings.count).to eq(1)
    end

    it "correctly merges gallery groups" do
      good_group = create(:gallery_group)
      bad_group = create(:gallery_group)

      create_list(:gallery, 3, gallery_groups: [good_group])
      create_list(:gallery, 2, gallery_groups: [bad_group])
      mutual = create(:gallery, gallery_groups: [good_group, bad_group])

      expect(good_group.galleries.count).to eq(4)
      expect(bad_group.galleries.count).to eq(3)

      good_group.merge_with(bad_group)

      expect(Tag.find_by_id(bad_group.id)).to be_nil
      expect(bad_group.galleries.count).to eq(0)
      expect(good_group.galleries.count).to eq(6)
      expect(mutual.gallery_groups.count).to eq(1)
    end
  end

  describe "validations" do
    it "requires unique name" do
      tag = create(:label)
      new_tag = build(:label, name: tag.name)
      expect(new_tag).not_to be_valid
    end

    it "requires unique case sensitive name" do
      tag = create(:label, name: 'CASE')
      new_tag = build(:label, name: tag.name.downcase)
      expect(new_tag).not_to be_valid
    end
  end

  describe "#id_for_select" do
    it "uses ID if persisted" do
      tag = create(:label)
      expect(tag.id_for_select).to eq(tag.id)
    end

    it "uses name with prepended underscore otherwise" do
      tag = build(:label, name: 'tag')
      expect(tag.id_for_select).to eq('_tag')
    end
  end

  describe "#post_count" do
    it "works" do
      tag1 = create(:label)
      tag2 = create(:label)
      create(:post, labels: [tag2])
      tag3 = create(:label)
      create_list(:post, 2, labels: [tag3])
      tags = [tag1, tag2, tag3]
      fetched = Label.where(id: tags.map(&:id)).ordered_by_id
      expect(fetched).to eq(tags)
      expect(fetched.map(&:post_count)).to eq([0, 1, 2])
    end
  end

  describe "#character_count" do
    def create_tags
      tag1 = create(:gallery_group)
      tag2 = create(:gallery_group)
      create(:character, gallery_groups: [tag2])
      tag3 = create(:gallery_group)
      create_list(:character, 2, gallery_groups: [tag3])
      [tag1, tag2, tag3]
    end

    it "works with with_character_counts scope" do
      tags = create_tags
      fetched = GalleryGroup.where(id: tags.map(&:id)).select(:id).ordered_by_id.with_character_counts
      expect(fetched).to eq(tags)
      expect(fetched.map{|x| x[:character_count] }).to eq([0, 1, 2])
    end

    it "works without with_character_counts scope" do
      tags = create_tags
      fetched = GalleryGroup.where(id: tags.map(&:id)).ordered_by_id
      expect(fetched).to eq(tags)
      expect(fetched.map(&:character_count)).to eq([0, 1, 2])
    end
  end
end
