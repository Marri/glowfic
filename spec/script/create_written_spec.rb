require Rails.root.join('script', 'create_written.rb').to_s

RSpec.describe "#create_writtens" do # rubocop:disable Rspec/DescribeClass
  it "skips posts that already have writtens" do
    create(:post)
    expect { create_writtens }.not_to change{Reply.count}
  end

  it "creates writtens for simple posts" do
    post = create(:post, skip_written: true)
    expect(post.written).to be_nil
    allow(STDOUT).to receive(:puts).with("Creating writtens for posts #{post.id} through #{post.id}")
    Timecop.freeze(Time.zone.now + 8.hours) do
      expect { create_writtens }.to change{Reply.count}.by(1)
    end
    written = Reply.last
    expect(written.reply_order).to eq(0)
    expect(written.user).to eq(post.user)
    expect(written.content).to eq(post.content)
    expect(written.icon_id).to be_nil
    expect(written.character_id).to be_nil
    expect(written.character_alias_id).to be_nil
    expect(written.created_at).to be_the_same_time_as(post.created_at)
    expect(written.updated_at).to be_the_same_time_as(post.edited_at)
  end

  it "creates correct writtens for complex posts" do
    user = create(:user)
    icon = create(:icon, user: user)
    character = create(:template_character, default_icon: icon, user: user)
    calias = create(:alias, character: character)

    post = create(:post, character: character, icon: icon, character_alias: calias, user: user, skip_written: true)
    Timecop.freeze(Time.zone.now + 4.hours) do
      post.update!(content: 'new content!')
    end
    expect(post.written).to be_nil

    allow(STDOUT).to receive(:puts).with("Creating writtens for posts #{post.id} through #{post.id}")
    Timecop.freeze(Time.zone.now + 8.hours) do
      expect { create_writtens }.to change{Reply.count}.by(1)
    end
    written = Reply.last
    expect(written.reply_order).to eq(0)
    expect(written.user).to eq(post.user)
    expect(written.content).to eq(post.content)
    expect(written.icon_id).to eq(icon.id)
    expect(written.character_id).to eq(character.id)
    expect(written.character_alias_id).to eq(calias.id)
    expect(written.created_at).to be_the_same_time_as(post.created_at)
    expect(written.updated_at).to be_the_same_time_as(post.edited_at)
  end

  context "with audits" do
    before(:each) do
      Post.auditing_enabled = true
      Reply.auditing_enabled = true
    end

    after(:each) do
      Post.auditing_enabled = false
      Reply.auditing_enabled = false
    end

    it "handles audits correctly" do
      user = create(:user)
      icon = create(:icon, user: user)
      character = create(:template_character, default_icon: icon, user: user)
      calias = create(:alias, character: character)

      post = create(:post, character: character, icon: icon, user: user, skip_written: true)

      Timecop.freeze(Time.zone.now + 2.hours) do
        post.update!(subject: 'new subject!')
      end

      Timecop.freeze(Time.zone.now + 4.hours) do
        post.update!(content: 'new content!')
      end

      Timecop.freeze(Time.zone.now + 6.hours) do
        post.update!(status: :complete)
      end

      Timecop.freeze(Time.zone.now + 8.hours) do
        post.update!(character_alias: calias)
      end
      expect(post.written).to be_nil

      allow(STDOUT).to receive(:puts).with("Creating writtens for posts #{post.id} through #{post.id}")
      Timecop.freeze(Time.zone.now + 12.hours) do
        expect { create_writtens }.to change{Reply.count}.by(1)
      end
      written = Reply.last
      expect(written.reply_order).to eq(0)
      expect(written.user).to eq(post.user)
      expect(written.content).to eq(post.content)
      expect(written.icon_id).to eq(icon.id)
      expect(written.character_id).to eq(character.id)
      expect(written.character_alias_id).to eq(calias.id)
      expect(written.created_at).to be_the_same_time_as(post.created_at)
      expect(written.updated_at).to be_the_same_time_as(post.edited_at)
      expect(written.audits.count).to eq(3)

      create_audit = written.audits.first
      expect(create_audit.action).to eq('create')
      expect(create_audit.audited_changes).to eq(post.audits.first.audited_changes)

      update_audit1 = written.audits.second
      expect(update_audit1.action).to eq('update')
      expect(update_audit1.audited_changes).to eq({'content' => ['test content', 'new content!']})

      update_audit2 = written.audits.third
      expect(update_audit2.action).to eq('update')
      expect(update_audit2.audited_changes).to eq({'character_alias_id' => [nil, calias.id]})
    end
  end

  it "handles multiple posts" do
    posts = create_list(:post, 30, with_character: true, with_icon: true, skip_written: true)
    allow(STDOUT).to receive(:puts).with("Creating writtens for posts #{posts.first.id} through #{posts.last.id}")

    Timecop.freeze(Time.zone.now + 8.hours) do
      expect { create_writtens }.to change{Reply.count}.by(30)
    end
  end
end
