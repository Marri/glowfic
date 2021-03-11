RSpec.describe "About pages", :type => :system do
  scenario "Terms of Service page" do
    visit tos_path
    within("#tos-content h1") do
      expect(page).to have_text("Glowfic Constellation Terms of Service")
    end
  end

  scenario "Privacy Policy page" do
    visit privacy_path
    within("#privacy-content h1") do
      expect(page).to have_text("Privacy")
    end
  end

  scenario "Contact Us page" do
    visit contact_path
    within("#contact-content h1") do
      expect(page).to have_text("Contact the Constellation")
    end
  end

  scenario "DMCA Policy page" do
    visit dmca_path
    within("#dmca-content h1") do
      expect(page).to have_text("Glowfic Constellation DMCA Policy")
    end
  end
end
