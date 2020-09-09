RSpec.describe Character do
  let(:user) { create(:user) }
  let(:character) { create(:character, user: user) }

  describe "validations" do
    let(:character) { build(:character) }

    it "requires valid group" do
      expect(character).to be_valid
      character.character_group_id = 0
      expect(character).not_to be_valid
    end

    it "requires valid default icon" do
      icon = create(:icon)
      expect(character).to be_valid
      character.default_icon = icon
      expect(character).not_to be_valid
    end

    it "requires valid galleries" do
      gallery = create(:gallery)
      character = create(:character)
      expect(character).to be_valid
      character.gallery_ids = [gallery.id]
      expect(character).not_to be_valid
    end

    it "strips facecast" do
      character = create(:character, pb: 'Chris Pine ')
      expect(character.reload.pb).to eq('Chris Pine')
    end
  end

  it "uniqs gallery images" do
    icon = create(:icon, user: user)
    gallery = create(:gallery, user: user)
    gallery.icons << icon
    expect(gallery.icons.map(&:id)).to eq([icon.id])
    character.galleries << gallery
    gallery = create(:gallery, user: user)
    gallery.icons << icon
    expect(gallery.icons.map(&:id)).to eq([icon.id])
    character.galleries << gallery
    expect(character.galleries.size).to eq(2)
    expect(character.icons.map(&:id)).to eq([icon.id])
  end

  describe "#editable_by?" do
    it "should be false for random user" do
      expect(character).not_to be_editable_by(create(:user))
    end

    it "should be true for owner" do
      expect(character).to be_editable_by(user)
    end

    it "should be true for admin" do
      expect(character).to be_editable_by(create(:admin_user))
    end
  end

  describe "#ungrouped_gallery_ids" do
    it "returns only galleries not added by groups" do
      gallery1 = create(:gallery, user: user)
      gallery2 = create(:gallery, user: user)

      CharactersGallery.create!(character: character, gallery: gallery1)
      CharactersGallery.create!(character: character, gallery: gallery2, added_by_group: true)

      character.reload
      expect(character.gallery_ids).to match_array([gallery1.id, gallery2.id])
      expect(character.ungrouped_gallery_ids).to match_array([gallery1.id])
    end
  end

  describe "#ungrouped_gallery_ids=" do
    let(:gallery) { create(:gallery, user: user) }
    let(:group) { create(:gallery_group) }
    let(:character) { create(:character, gallery_groups: [group], user: user) }

    it "adds unattached galleries" do
      character = create(:character, user: user)
      expect(character.gallery_ids).to eq([])
      expect(character.ungrouped_gallery_ids).to eq([])
      character.update!(ungrouped_gallery_ids: [gallery.id])

      character.reload
      expect(character.characters_galleries.map(&:added_by_group?)).to match_array([false])
      expect(character.gallery_ids).to match_array([gallery.id])
      expect(character.ungrouped_gallery_ids).to match_array([gallery.id])
    end

    it "sets already-attached galleries to not be added_by_group" do
      # does not add a new attachment
      gallery = create(:gallery, gallery_groups: [group], user: user)

      character.reload
      expect(character.gallery_ids).to match_array([gallery.id])
      expect(character.ungrouped_gallery_ids).to match_array([])

      character.update!(ungrouped_gallery_ids: [gallery.id])
      character.reload

      expect(character.gallery_ids).to match_array([gallery.id])
      expect(character.ungrouped_gallery_ids).to match_array([gallery.id])
      expect(character.characters_galleries.map(&:added_by_group)).to match_array([false])
    end

    context "with mixed galleries" do
      let(:gallery_manual) { create(:gallery, user: user) }
      let(:gallery_both) { create(:gallery, gallery_groups: [group], user: user) }
      let(:gallery_automatic) { create(:gallery, gallery_groups: [group], user: user) }

      before(:each) do
        CharactersGallery.create!(character: character, gallery: gallery_manual)
        character.characters_galleries.where(gallery_id: gallery_both.id).update_all(added_by_group: false) # rubocop:disable Rails/SkipsModelValidations

        character.reload
        expect(character.gallery_ids).to match_array([gallery_manual.id, gallery_both.id, gallery_automatic.id]) # rubocop:disable RSpec/ExpectInHook
        expect(character.ungrouped_gallery_ids).to match_array([gallery_manual.id, gallery_both.id]) # rubocop:disable RSpec/ExpectInHook
      end

      it "removes associated galleries when not present only if not also present in groups, otherwise sets flag" do
        # does not remove gallery_manual when not told to
        # sets flag on gallery_both to be added_by_group
        # does not remove gallery_auto despite not being present
        character.update!(ungrouped_gallery_ids: [gallery_manual.id])

        character.reload
        expect(character.gallery_ids).to match_array([gallery_manual.id, gallery_both.id, gallery_automatic.id])
        expect(character.ungrouped_gallery_ids).to match_array([gallery_manual.id])
        expect(character.characters_galleries.find_by(gallery_id: gallery_both.id)).to be_added_by_group
      end

      it "does nothing if unchanged" do
        # does not remove or change the status of any of: gallery_manual, gallery_both, gallery_auto
        character.update!(ungrouped_gallery_ids: [gallery_manual.id, gallery_both.id])

        character.reload
        expect(character.gallery_ids).to match_array([gallery_manual.id, gallery_both.id, gallery_automatic.id])
        expect(character.ungrouped_gallery_ids).to match_array([gallery_manual.id, gallery_both.id])
      end
    end

    it "deletes manually-added galleries when not present" do
      character = create(:character, user: user, galleries: [gallery])

      character.reload
      expect(character.gallery_ids).to eq([gallery.id])
      expect(character.ungrouped_gallery_ids).to eq([gallery.id])
      character.ungrouped_gallery_ids = []
      character.save!

      character.reload
      expect(character.gallery_ids).to eq([])
    end

    ['before', 'after'].each do |time|
      context "combined #{time} gallery_group_ids" do
        let(:group1) { create(:gallery_group) }
        let(:group2) { create(:gallery_group) }

        def process_changes(obj, gallery_group_ids, ungrouped_gallery_ids, time)
          if time == 'before'
            obj.ungrouped_gallery_ids = ungrouped_gallery_ids
            obj.gallery_group_ids = gallery_group_ids
          else
            obj.gallery_group_ids = gallery_group_ids
            obj.ungrouped_gallery_ids = ungrouped_gallery_ids
          end
        end

        it "supports adding a gallery at the same time as removing its group" do
          gallery = create(:gallery, user: user, gallery_groups: [group])
          expect(character.reload.galleries).to match_array([gallery])

          process_changes(character, [], [gallery.id], time)
          character.save!

          character.reload
          expect(character.galleries).to match_array([gallery])
          expect(character.ungrouped_gallery_ids).to match_array([gallery.id])
          expect(character.gallery_groups).to match_array([])
        end

        it "supports adding a gallery at the same time as swapping its group" do
          gallery = create(:gallery, user: user, gallery_groups: [group1, group2])
          character = create(:character, user: user, gallery_groups: [group1])
          expect(character.reload.galleries).to match_array([gallery])

          process_changes(character, [group2.id], [gallery.id], time)
          character.save!

          character.reload
          expect(character.galleries).to match_array([gallery])
          expect(character.ungrouped_gallery_ids).to match_array([gallery.id])
          expect(character.gallery_groups).to match_array([group2])
        end

        it "keeps a gallery when removing at the same time as adding its group" do
          gallery = create(:gallery, user: user, gallery_groups: [group])
          character = create(:character, user: user, galleries: [gallery])
          expect(character.reload.galleries).to match_array([gallery])

          process_changes(character, [group.id], [], time)
          character.save!

          character.reload
          expect(character.galleries).to match_array([gallery])
          expect(character.ungrouped_gallery_ids).to match_array([])
          expect(character.gallery_groups).to match_array([group])
        end

        it "keeps a gallery when removing at the same time as swapping its group" do
          gallery = create(:gallery, user: user, gallery_groups: [group1, group2])
          character = create(:character, user: user, galleries: [gallery], gallery_groups: [group1])
          expect(character.reload.galleries).to match_array([gallery])

          process_changes(character, [group2.id], [], time)
          character.save!

          character.reload
          expect(character.galleries).to match_array([gallery])
          expect(character.ungrouped_gallery_ids).to match_array([])
          expect(character.gallery_groups).to match_array([group2])
        end
      end
    end
  end

  describe "audits" do
    before(:each) do
      Character.auditing_enabled = true
      expect(Audited::Audit.count).to eq(0) # rubocop:disable RSpec/ExpectInHook
    end

    after(:each) { Character.auditing_enabled = false }

    it "is not created on create" do
      create(:character)
      Audited.audit_class.as_user(create(:user)) { create(:character) }
      expect(Audited::Audit.count).to eq(0)
    end

    it "is only created on mod update" do
      Audited.audit_class.as_user(user) do
        character.update!(name: character.name + 'notmod')
      end
      Audited.audit_class.as_user(create(:user)) do
        character.update!(name: character.name + 'mod', audit_comment: 'mod')
      end
      expect(Audited::Audit.count).to eq(1)
    end

    it "is not created on destroy" do
      Audited.audit_class.as_user(create(:user)) do
        character.destroy!
      end
      expect(Audited::Audit.count).to eq(0)
    end
  end

  describe "#galleries" do
    it "updates order when adding galleries" do
      galleries = create_list(:gallery, 2, user: user)
      char = create(:character, user: user)
      char.update!(galleries: galleries)
      expect(galleries.map {|g| char.character_gallery_for(g.id).section_order}).to eq([0, 1])
    end

    it "updates order when removing galleries" do
      galleries = create_list(:gallery, 3, user: user)
      char = create(:character, user: user, galleries: galleries)
      char.update!(galleries: [galleries[0], galleries[2]])
      expect(galleries.map {|g| char.character_gallery_for(g.id)&.section_order}).to eq([0, nil, 1])
      # make sure it didn't destroy the removed gallery
      expect(Gallery.find_by(id: galleries[1].id)).to eq(galleries[1])
    end
  end

  it "orders icons by default" do
    user = create(:user)
    char = create(:character, user: user)
    gallery1 = create(:gallery, user: user)
    gallery2 = create(:gallery, user: user)
    char.update!(galleries: [gallery1, gallery2])
    icon2 = create(:icon, user: user, keyword: 'b', galleries: [gallery1])
    icon3 = create(:icon, user: user, keyword: 'c', galleries: [gallery2, gallery1])
    icon4 = create(:icon, user: user, keyword: 'd', galleries: [gallery1, gallery2])
    icon1 = create(:icon, user: user, keyword: 'a', galleries: [gallery2])
    expect(char.icons).to eq([icon1, icon2, icon3, icon4])
  end
end
