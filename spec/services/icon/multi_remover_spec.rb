require "spec_helper"

RSpec.describe Icon::MultiRemover do
  let(:user) { create(:user) }
  let(:deleter) { Icon::MultiRemover.new }

  it "requires icons" do
    deleter.perform({}, user: create(:user))
    expect(deleter.errors.full_messages).to eq(["No icons selected."])
  end

  it "requires valid icons" do
    icon = create(:icon)
    icon.destroy!
    params = { marked_ids: [0, '0', 'abc', -1, '-1', icon.id, create(:icon).id] }
    deleter.perform(params, user: icon.user)
    expect(deleter.errors.full_messages).to eq(["No icons selected."])
  end

  context "removing icons from a gallery" do
    it "requires gallery" do
      icon = create(:icon, user: user)
      params = { marked_ids: [icon.id], gallery_delete: true }
      deleter.perform(params, user: user)
      expect(deleter.errors.full_messages).to eq(["Gallery could not be found."])
    end

    it "requires your gallery" do
      icon = create(:icon, user: user)
      gallery = create(:gallery)
      params = { marked_ids: [icon.id], gallery_id: gallery.id, gallery_delete: true }
      deleter.perform(params, user: user)
      expect(deleter.errors.full_messages).to eq(["Gallery is not yours."])
    end

    it "skips other people's icons" do
      icon = create(:icon)
      icon2 = create(:icon, user: user)
      gallery = create(:gallery, user: user)
      gallery.icons << icon
      gallery.icons << icon2
      icon.reload
      expect(icon.galleries.count).to eq(1)
      params = { marked_ids: [icon.id, icon2.id], gallery_id: gallery.id, gallery_delete: true }
      deleter.perform(params, user: user)
      expect(icon.reload.galleries.count).to eq(1)
    end

    it "removes int ids from gallery" do
      icon = create(:icon, user: user)
      gallery = create(:gallery, user: user)
      gallery.icons << icon
      expect(icon.galleries.count).to eq(1)
      params = { marked_ids: [icon.id], gallery_id: gallery.id, gallery_delete: true }
      deleter.perform(params, user: user)
      expect(icon.galleries.count).to eq(0)
      expect(deleter.errors).to be_blank
    end

    it "removes string ids from gallery" do
      icon = create(:icon, user: user)
      gallery = create(:gallery, user: user)
      gallery.icons << icon
      expect(icon.galleries.count).to eq(1)
      params = { marked_ids: [icon.id.to_s], gallery_id: gallery.id, gallery_delete: true }
      deleter.perform(params, user: user)
      expect(icon.galleries.count).to eq(0)
      expect(deleter.errors).to be_blank
    end
  end

  context "deleting icons from the site" do
    it "skips other people's icons" do
      icon = create(:icon)
      params = { marked_ids: [icon.id, create(:icon, user: user).id] }
      deleter.perform(params, user: user)
      icon.reload
    end

    it "removes int ids from gallery" do
      icon = create(:icon, user: user)
      params = { marked_ids: [icon.id] }
      deleter.perform(params, user: user)
      expect(deleter.errors).to be_blank
      expect(Icon.find_by_id(icon.id)).to be_nil
    end

    it "removes string ids from gallery" do
      icon = create(:icon, user: user)
      icon2 = create(:icon, user: user)
      params = { marked_ids: [icon.id.to_s, icon2.id.to_s] }
      deleter.perform(params, user: user)
      expect(deleter.errors).to be_blank
      expect(Icon.find_by_id(icon.id)).to be_nil
      expect(Icon.find_by_id(icon2.id)).to be_nil
    end
  end
end
