RSpec.describe Tag do
  describe "#merge_with" do
    it "takes the correct actions" do
      good_tag = create(:label)
      bad_tag = create(:label)

      # TODO handle properly with nested attributes
      create_list(:post, 3, labels: [good_tag])
      create_list(:post, 2, labels: [bad_tag])

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
      tags = create_list(:label, 3)
      create(:post, labels: [tags[1]])
      create_list(:post, 2, labels: [tags[2]])
      fetched = Label.where(id: tags.map(&:id)).ordered_by_id
      expect(fetched).to eq(tags)
      expect(fetched.map(&:post_count)).to eq([0, 1, 2])
    end
  end

  describe "#character_count" do
    def create_tags
      tags = create_list(:gallery_group, 3)
      create(:character, gallery_groups: [tags[1]])
      create_list(:character, 2, gallery_groups: [tags[2]])
      tags
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
