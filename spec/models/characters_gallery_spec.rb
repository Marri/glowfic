RSpec.describe CharactersGallery do
  let(:user) { create(:user) }
  let(:character) { create(:character, user: user) }
  let(:gallery) { create(:gallery, user: user) }

  it "should reset section_order fields in other galleries after deletion" do
    cg0, cg1, cg2 = Array.new(3) { create(:characters_gallery, character: character, gallery: create(:gallery, user: user)) }
    expect([cg0, cg1, cg2].map(&:section_order)).to eq([0, 1, 2])
    cg1.destroy!

    expect(cg0.reload.section_order).to eq(0)
    expect(cg2.reload.section_order).to eq(1)
  end

  it "should autofill gallery order" do
    cgs = Array.new(3) { create(:characters_gallery, character: character, gallery: create(:gallery, user: user)) }
    expect(cgs.map(&:section_order)).to eq([0, 1, 2])
  end

  it "should prevent duplicate joins for the same character and gallery" do
    gallery = create(:gallery, user: user)
    character.galleries << gallery
    cg = character.characters_galleries.create(gallery: gallery)
    expect(cg.persisted?).to be(false)
    expect(cg).not_to be_valid
    expect(cg.errors.messages).to eq({character: ['has already been taken']})
  end

  it "should allow multiple galleries on the same character" do
    character.galleries << create(:gallery, user: user)
    gallery2 = create(:gallery, user: user)
    cg = character.characters_galleries.create(gallery: gallery2)
    expect(cg.persisted?).to be(true)
    expect(cg).to be_valid
  end

  it "should allow multiple characters to have the same gallery" do
    character.galleries << gallery
    character2 = create(:character, user: user)
    cg = character2.characters_galleries.create(gallery: gallery)
    expect(cg.persisted?).to be(true)
    expect(cg).to be_valid
  end
end
