RSpec.describe GalleryTag do
  describe "callbacks" do
    let(:user) { create(:user) }
    let(:group) { create(:gallery_group) }
    let(:group2) { create(:gallery_group) }

    context "when gallery group added to gallery" do
      it "does not add to other users' characters" do
        character = create(:character, gallery_groups: [group])
        create(:gallery, gallery_groups: [group])
        expect(character.reload.galleries).to match_array([])
      end

      it "does not add to a character twice" do
        # tests a manually-attached character1
        # and a double-grouped character2
        character1 = create(:character, user: user, gallery_groups: [group])
        character2 = create(:character, user: user, gallery_groups: [group, group2])

        gallery = create(:gallery, user: user, characters: [character1], gallery_groups: [group])
        gallery.reload
        expect(gallery.characters).to match_array([character1, character2])
        expect(gallery.characters_galleries.find_by(character_id: character1.id)).not_to be_added_by_group
        expect(gallery.characters_galleries.find_by(character_id: character2.id)).to be_added_by_group

        gallery.gallery_groups << group2
        gallery.save!
        gallery.reload
        expect(gallery.characters).to match_array([character1, character2])
        expect(gallery.characters_galleries.find_by(character_id: character1.id)).not_to be_added_by_group
        expect(gallery.characters_galleries.find_by(character_id: character2.id)).to be_added_by_group
      end

      it "adds galleries to given group" do
        characters = create_list(:character, 2, user: user, gallery_groups: [group])
        gallery = create(:gallery, user: user, gallery_groups: [group])
        gallery.reload
        expect(gallery.characters).to match_array(characters)
        expect(gallery.characters_galleries.map(&:added_by_group?)).to eq([true, true])
      end
    end

    it "does right things when gallery group removed from gallery" do
      # does not touch unrelated characters
      # does not touch characters that have been otherwise tethered
      # removes from characters that are not otherwise tethered
      other_character = create(:character, user: user)
      gallery = create(:gallery, user: user, gallery_groups: [group], characters: [other_character])
      character_auto = create(:character, user: user, gallery_groups: [group])
      character_both = create(:character, user: user, gallery_groups: [group])
      gallery.reload
      gallery.characters_galleries.find_by(character_id: character_both.id).update!(added_by_group: false)
      expect(gallery.characters).to match_array([other_character, character_auto, character_both])
      expect(gallery.characters_galleries.find_by(character_id: character_auto.id)).to be_added_by_group

      gallery.update!(gallery_groups: [])
      gallery.reload
      expect(gallery.characters).to match_array([other_character, character_both])
      expect(gallery.characters_galleries.find_by(character_id: character_both.id)).not_to be_added_by_group
    end

    it "does not destroy gallery groups when destroyed" do
      gallery = create(:gallery, gallery_groups: [group])
      other = create(:gallery, gallery_groups: [group])
      gallery.reload
      other.reload
      expect(gallery.gallery_groups).to match_array([group])
      expect(other.gallery_groups).to match_array([group])

      gallery.destroy!
      group.reload
      expect(other.reload.gallery_groups).to match_array([group])
    end
  end
end
