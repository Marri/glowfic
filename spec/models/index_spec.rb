RSpec.describe Index do
  let(:index) { create(:index, authors_locked: true) }
  let(:user) { create(:user) }

  describe "destroy behavior" do
    let!(:section) { create(:index_section, index: index) }
    let!(:post) { create(:post) }
    let!(:sectionpost) { create(:index_post, index_section: section, index: index, post: post) }

    before(:each) do
      create(:index_post, index: index)
    end

    it "should destroy indexposts and indexsections when deleting an index" do
      expect { index.destroy! }
        .to change{ Index.count }.by(-1)
        .and change{ IndexPost.count }.by(-2)
        .and change{ IndexSection.count }.by(-1)
        .and not_change{ Post.count }
    end

    it "should relocate indexposts when deleting an indexsection" do
      expect { section.destroy! }
        .to not_change { [Index.count, IndexPost.count, Post.count] }
        .and change{ IndexSection.count }.by(-1)
    end

    it "should affect nothing else when deleting an indexpost" do
      other = create(:index_post, index_section: section, index: index)
      expect(sectionpost.section_order).to eq(0)
      expect(other.section_order).to eq(1)

      expect { sectionpost.destroy! }
        .to change{ IndexPost.count }.by(-1)
        .and not_change { [Index.count, IndexSection.count, Post.count] }

      expect(other.reload.section_order).to eq(0)
    end

    it "should delete indexposts when deleting a post" do
      expect { post.destroy! }
        .to change{ Post.count }.by(-1)
        .and change{ IndexPost.count }.by(-1)
        .and not_change{ [Index.count, IndexSection.count] }
    end
  end

  describe "#editable_by?" do
    it "requires a user" do
      expect(index.editable_by?(nil)).to eq(false)
    end

    it "returns true if index is open" do
      index.update!(authors_locked: false)
      expect(index.editable_by?(user)).to eq(true)
    end

    it "returns true for creator" do
      expect(index.editable_by?(index.user)).to eq(true)
    end

    it "returns true for admins" do
      expect(index.editable_by?(create(:admin_user))).to eq(true)
    end

    it "returns false for others" do
      expect(index.editable_by?(user)).to eq(false)
    end
  end

  describe "#visible_to?" do
    it "returns true if index is public" do
      expect(index.visible_to?(nil)).to eq(true)
    end

    it "requires a user" do
      index.update!(privacy: :registered)
      expect(index.visible_to?(nil)).to eq(false)
    end

    it "returns true if index is registered" do
      index.update!(privacy: :registered)
      expect(index.visible_to?(user)).to eq(true)
    end

    it "returns true for admins" do
      index.update!(privacy: :private)
      expect(index.visible_to?(create(:admin_user))).to eq(true)
    end

    it "returns true for creator" do
      index.update!(privacy: :private)
      expect(index.visible_to?(index.user)).to eq(true)
    end
  end
end
