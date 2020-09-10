RSpec.describe Template do
  it "requires a name" do
    template = build(:template, name: nil)
    expect(template).not_to be_valid
    expect {
      template.save!
    }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Name can't be blank")
    expect(Template.count).to eq(0)
  end

  it "requires a user" do
    template = build(:template, user_id: 999)
    expect(template).not_to be_valid
    expect {
      template.save!
    }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: User must exist")
    expect(Template.count).to eq(0)
  end

  it "succeeds without characters" do
    template = build(:template, characters: [])
    expect(template).to be_valid
    expect {
      template.save!
    }.not_to raise_error
    expect(Template.first).to eq(template.reload)
  end

  it "orders characters when given" do
    template = create(:template)
    character3 = create(:character, name: 'c', template: template)
    character1 = create(:character, name: 'a', template: template)
    character2 = create(:character, name: 'b', template: template)
    expect(template.characters).to eq([character1, character2, character3])
  end

  describe "#plucked characters" do
    it "returns nothing for an empty template" do
      template = create(:template)
      expect(template.plucked_characters).to be_empty
    end

    it "returns info for a single character" do
      template = create(:template)
      character = create(:character, template: template, nickname: "nickname", screenname: "screen_name")
      info = [[character.id, "#{character.name} | #{character.nickname} | #{character.screenname}"]]
      expect(template.plucked_characters).to eq(info)
    end

    it "returns info for multiple characters" do
      template = create(:template)
      character1 = create(:character, template: template, name: 'AAAA')
      character2 = create(:character, template: template, nickname: "nickname", name: 'BBBB')
      character3 = create(:character, template: template, screenname: "screen_name", name: 'CCCC')
      info = [
        [character1.id, character1.name],
        [character2.id, "#{character2.name} | #{character2.nickname}"],
        [character3.id, "#{character3.name} | #{character3.screenname}"]
      ]
      expect(template.plucked_characters).to eq(info)
    end

    it "excludes retired characters" do
      template = create(:template)
      character1 = create(:character, template: template, name: 'AAAA')
      character2 = create(:character, template: template, nickname: "nickname", name: 'BBBB')
      create(:character, template: template, retired: true)
      info = [
        [character1.id, character1.name],
        [character2.id, "#{character2.name} | #{character2.nickname}"],
      ]
      expect(template.plucked_characters).to eq(info)
    end
  end

  it "cleans up when deleted" do
    template = create(:template)
    create_list(:character, 2, template: template)
    old_id = template.id
    template.destroy!
    expect(Character.where(template_id: old_id)).to be_empty
  end
end
