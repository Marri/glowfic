RSpec.describe "Seeding database", :type => :system do
  scenario "Loading seed data throws no errors" do
    allow(STDOUT).to receive(:puts)
    DatabaseCleaner.clean_with(:truncation)
    Rails.application.load_seed
  end
end
