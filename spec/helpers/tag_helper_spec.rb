RSpec.describe TagHelper do
  describe "#delete_path" do
    let(:tag) { create(:setting) }

    it "returns the right url with no params" do
      expect(helper.delete_path(tag)).to eq(tag_path(tag))
    end

    it "returns the right url with a page" do
      without_partial_double_verification do
        allow(helper).to receive(:params).and_return({page: 2})
        allow(helper).to receive(:page).and_return(2)
      end
      expect(helper.delete_path(tag)).to eq(tag_path(tag, {page: 2}))
    end

    it "returns the right url with a view" do
      assign(:view, 'Setting')
      expect(helper.delete_path(tag)).to eq(tag_path(tag, {view: 'Setting'}))
    end
  end
end
