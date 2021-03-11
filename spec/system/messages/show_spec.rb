RSpec.describe "Message threads", :type => :system do
  scenario "User views a message thread" do
    user = login

    first = create(:message, sender: user)
    create(:message, thread_id: first.id, sender: first.recipient, recipient: user) # second
    create(:message, thread_id: first.id, sender: user, recipient: first.recipient) # third

    visit messages_path(view: 'inbox')
    expect(page).to have_selector('tr.message-row', count: 1)
    within("table") do
      click_link first.unempty_subject
    end
    expect(page).to have_selector('.message-collapse', count: 3)

    create(:message, thread_id: first.id, sender: user, recipient: first.recipient, message: "abcde" * 22) # long
    visit messages_path(view: 'outbox')
    within("table") do
      click_link first.unempty_subject
    end
    expect(page).to have_selector('.message-collapse', count: 4)
    short = ("abcde" * 15)[0...73] + "…"
    expect(page).to have_selector('.message-collapse', text: short)
    expect(page).to have_no_selector('.message-collapse', text: "abcde" * 20)
  end

  scenario "ordering of inbox messages within threading" do
    user = login
    first = create(:message, recipient: user, subject: 'first')
    create(:message, recipient: user, subject: 'second') # second

    visit messages_path(view: 'inbox')
    expect(page).to have_selector('tr.message-row', count: 2)
    table_rows = page.all(:css, 'tr.message-row')
    expect(table_rows[0]).to have_text('second')
    expect(table_rows[1]).to have_text('first')

    create(:message, thread_id: first.id, recipient: user, sender: first.sender) # third
    visit messages_path(view: 'inbox')
    expect(page).to have_selector('tr.message-row', count: 2)
    table_rows = page.all(:css, 'tr.message-row')
    expect(table_rows[0]).to have_text('first')
    expect(table_rows[1]).to have_text('second')
  end

  scenario "ordering of outbox messages within threading" do
    user = login
    first = create(:message, sender: user, subject: 'first')
    create(:message, sender: user, subject: 'second') # second

    visit messages_path(view: 'outbox')
    expect(page).to have_selector('tr.message-row', count: 2)
    table_rows = page.all(:css, 'tr.message-row')
    expect(table_rows[0]).to have_text('second')
    expect(table_rows[1]).to have_text('first')

    create(:message, thread_id: first.id, recipient: first.recipient, sender: user) # third
    visit messages_path(view: 'outbox')
    expect(page).to have_selector('tr.message-row', count: 2)
    table_rows = page.all(:css, 'tr.message-row')
    expect(table_rows[0]).to have_text('first')
    expect(table_rows[1]).to have_text('second')
  end
end
