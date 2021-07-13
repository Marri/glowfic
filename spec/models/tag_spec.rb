RSpec.describe Tag do
  describe "#merge_with" do
    it "takes the correct actions" do
      good_tag = create(:label)
      bad_tag = create(:label)

      # TODO handle properly with nested attributes
      create(:post, label_ids: [good_tag.id], setting_ids: [], content_warning_ids: [])
      create(:post, label_ids: [good_tag.id], setting_ids: [], content_warning_ids: [])
      create(:post, label_ids: [good_tag.id], setting_ids: [], content_warning_ids: [])
      create(:post, label_ids: [bad_tag.id], setting_ids: [], content_warning_ids: [])
      create(:post, label_ids: [bad_tag.id], setting_ids: [], content_warning_ids: [])

      expect(good_tag.posts.count).to eq(3)
      expect(bad_tag.posts.count).to eq(2)

      good_tag.merge_with(bad_tag)

      expect(Tag.find_by_id(bad_tag.id)).to be_nil
      expect(bad_tag.posts.count).to eq(0)
      expect(good_tag.posts.count).to eq(5)
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
      expect(fetched.map{|x| x[:character_count] }).to eq([0, 1, 2]) # rubocop:disable Rails/Pluck
    end

    it "works without with_character_counts scope" do
      tags = create_tags
      fetched = GalleryGroup.where(id: tags.map(&:id)).ordered_by_id
      expect(fetched).to eq(tags)
      expect(fetched.map(&:character_count)).to eq([0, 1, 2])
    end
  end

  describe "#editable_by?" do
    let(:tag) { create(:label) }
    let(:user) { create(:user) }

    it "requires login" do
      expect(tag.editable_by?(nil)).to eq(false)
    end

    it "returns true for creator" do
      expect(tag.editable_by?(tag.user)).to eq(true)
    end

    it "returns true for admin" do
      admin = create(:admin_user)
      expect(tag.editable_by?(admin)).to eq(true)
    end

    it "returns false for other users for non-settings" do
      expect(tag.editable_by?(user)).to eq(false)
    end

    it "returns true for unowned settings" do
      tag = create(:setting, owned: false)
      expect(tag.editable_by?(user)).to eq(true)
    end

    it "returns false for owned settings" do
      tag = create(:setting, owned: true)
      expect(tag.editable_by?(user)).to eq(false)
    end
  end

  describe "#deletable_by?" do
    let(:tag) { create(:label) }
    let(:user) { create(:user) }

    it "requires login" do
      expect(tag.deletable_by?(nil)).to eq(false)
    end

    it "returns true for creator" do
      expect(tag.deletable_by?(tag.user)).to eq(true)
    end

    it "returns true for admin" do
      admin = create(:admin_user)
      expect(tag.deletable_by?(admin)).to eq(true)
    end

    it "returns false for other user" do
      expect(tag.deletable_by?(user)).to eq(false)
    end
  end
end
