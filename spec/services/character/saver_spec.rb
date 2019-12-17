require "spec_helper"

RSpec.shared_examples "character" do |method|
  let(:user) { create(:user) }
  let(:character) {
    if method == 'update!'
      create(:character, user: user)
    else
      build(:character, user: user)
    end
  }
  let(:params) { ActionController::Parameters.new({ id: character.id }) }

  it "fails with invalid params" do
    params[:character] = {name: ''}
    saver = Character::Saver.new(character, user: user, params: params)
    expect { saver.send(method) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "fails with invalid template params" do
    new_name = character.name + 'aaa'

    params[:new_template] = '1'
    params[:character] = { template_attributes: {name: ''}, name: new_name }

    saver = Character::Saver.new(character, user: user, params: params)
    expect { saver.send(method) }.to raise_error(ActiveRecord::RecordInvalid)

    if method == 'create!'
      expect(saver.character.id).to be_nil
    else
      expect(character.reload.name).not_to eq(new_name)
    end
  end

  it "succeeds when valid" do
    new_name = character.name + 'aaa'
    template = create(:template, user: user)
    gallery = create(:gallery, user: user)
    setting = create(:setting, name: 'Another World')

    params[:character] = {
      name: new_name,
      template_name: 'TemplateName',
      screenname: 'a-new-test',
      setting_ids: [setting.id],
      template_id: template.id,
      pb: 'Actor',
      description: 'Description',
      ungrouped_gallery_ids: [gallery.id]
    }

    saver = Character::Saver.new(character, user: user, params: params)

    expect { saver.send(method) }.not_to raise_error

    character.reload
    expect(character.name).to eq(new_name)
    expect(character.template_name).to eq('TemplateName')
    expect(character.screenname).to eq('a-new-test')
    expect(character.settings.pluck(:name)).to eq(['Another World'])
    expect(character.template).to eq(template)
    expect(character.pb).to eq('Actor')
    expect(character.description).to eq('Description')
    expect(character.galleries).to match_array([gallery])
  end

  it "adds galleries by groups" do
    group = create(:gallery_group)
    gallery = create(:gallery, gallery_groups: [group], user: user)

    params[:character] = { gallery_group_ids: [group.id] }

    saver = Character::Saver.new(character, user: user, params: params)

    expect { saver.send(method) }.not_to raise_error

    character.reload
    expect(character.gallery_groups).to match_array([group])
    expect(character.galleries).to match_array([gallery])
    expect(character.ungrouped_gallery_ids).to be_blank
    expect(character.characters_galleries.first).to be_added_by_group
  end

  it "creates new templates when specified" do
    expect(Template.count).to eq(0)

    params[:new_template] = '1'
    params[:character] = { template_attributes: {name: 'Test'} }

    saver = Character::Saver.new(character, user: user, params: params)
    expect { saver.send(method) }.not_to raise_error

    expect(Template.count).to eq(1)
    expect(Template.first.name).to eq('Test')
    expect(character.reload.template_id).to eq(Template.first.id)
  end

  it "works when adding both group and gallery" do
    group = create(:gallery_group)
    gallery = create(:gallery, gallery_groups: [group], user: user)

    params[:character] = { gallery_group_ids: [group.id], ungrouped_gallery_ids: [gallery.id] }

    saver = Character::Saver.new(character, user: user, params: params)
    expect { saver.send(method) }.not_to raise_error

    character.reload
    expect(character.gallery_groups).to match_array([group])
    expect(character.galleries).to match_array([gallery])
    expect(character.ungrouped_gallery_ids).to eq([gallery.id])
    expect(character.characters_galleries.first).not_to be_added_by_group
  end

  it "does not add another user's galleries" do
    group = create(:gallery_group)
    create(:gallery, gallery_groups: [group]) # gallery

    params[:character] = { gallery_group_ids: [group.id] }

    saver = Character::Saver.new(character, user: user, params: params)
    expect { saver.send(method) }.not_to raise_error

    character.reload
    expect(character.gallery_groups).to match_array([group])
    expect(character.galleries).to be_blank
  end

  it "orders settings by default" do
    setting1 = create(:setting)
    setting3 = create(:setting)
    setting2 = create(:setting)

    params[:character] = { setting_ids: [setting1, setting2, setting3].map(&:id) }

    saver = Character::Saver.new(character, user: user, params: params)
    expect { saver.send(method) }.not_to raise_error

    expect(character.settings).to eq([setting1, setting2, setting3])
  end

  it "orders gallery groups by default" do
    group4 = create(:gallery_group, user: user)
    group1 = create(:gallery_group, user: user)
    group3 = create(:gallery_group, user: user)
    group2 = create(:gallery_group, user: user)

    params[:character] = { gallery_group_ids: [group1, group2, group3, group4].map(&:id) }

    saver = Character::Saver.new(character, user: user, params: params)
    expect { saver.send(method) }.not_to raise_error

    expect(character.gallery_groups).to eq([group1, group2, group3, group4])
  end
end

RSpec.describe Character::Saver do
  describe "create" do
    it_behaves_like "character", 'create!'
  end

  describe "update" do
    let(:user) { create(:user) }
    let(:character) { create(:character, user: user) }
    let(:params) { ActionController::Parameters.new({ id: character.id }) }

    it_behaves_like "character", 'update!'

    it "removes gallery only if not shared between groups" do
      group1 = create(:gallery_group) # gallery1
      group2 = create(:gallery_group) # -> gallery1
      group3 = create(:gallery_group) # gallery2 ->
      group4 = create(:gallery_group) # gallery2
      gallery1 = create(:gallery, gallery_groups: [group1, group2], user: user)
      gallery2 = create(:gallery, gallery_groups: [group3, group4], user: user)
      character.update!(gallery_groups: [group1, group3, group4])

      params[:character] = {gallery_group_ids: [group2.id, group4.id]}

      saver = Character::Saver.new(character, user: user, params: params)
      expect { saver.update! }.not_to raise_error

      character.reload
      expect(character.gallery_groups).to match_array([group2, group4])
      expect(character.galleries).to match_array([gallery1, gallery2])
      expect(character.ungrouped_gallery_ids).to be_blank
      expect(character.characters_galleries.map(&:added_by_group)).to eq([true, true])
    end

    it "does not remove gallery if tethered by group" do
      group = create(:gallery_group)
      gallery = create(:gallery, gallery_groups: [group], user: user)
      character.update!(gallery_groups: [group], ungrouped_gallery_ids: [gallery.id])
      expect(character.characters_galleries.first).not_to be_added_by_group

      params[:character] = {ungrouped_gallery_ids: [''], gallery_group_ids: [group.id]}

      saver = Character::Saver.new(character, user: user, params: params)
      expect { saver.update! }.not_to raise_error

      character.reload
      expect(character.gallery_groups).to match_array([group])
      expect(character.galleries).to match_array([gallery])
      expect(character.ungrouped_gallery_ids).to be_blank
      expect(character.characters_galleries.first).to be_added_by_group
    end

    it "reorders galleries as necessary" do
      g1 = create(:gallery, user: user)
      g2 = create(:gallery, user: user)
      character.galleries << g1
      character.galleries << g2
      g1_cg = CharactersGallery.find_by(gallery_id: g1.id)
      g2_cg = CharactersGallery.find_by(gallery_id: g2.id)
      expect(g1_cg.section_order).to eq(0)
      expect(g2_cg.section_order).to eq(1)

      params[:character] = {ungrouped_gallery_ids: [g2.id.to_s]}

      saver = Character::Saver.new(character, user: user, params: params)
      expect { saver.update! }.not_to raise_error

      expect(character.reload.galleries.pluck(:id)).to eq([g2.id])
      expect(g2_cg.reload.section_order).to eq(0)
    end
  end
end
