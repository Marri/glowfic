RSpec.describe DailyReport do
  describe "#posts" do
    default_zone = Time.zone
    {
      # 2017-11-05 10:00, clock goes back in Eastern
      "without timezone" => [default_zone, [2017, 11, 5, 10, 0]],
      # 2017-10-29 10:00, clock goes back in GMT/BST
      "with timezone"    => ["Europe/London", [2017, 10, 29, 10, 0]]
    }.each do |name, data|
      zone = data.first
      dst_day_params = data.last
      context name do
        before(:each) { Time.zone = zone }

        after(:each) { Time.zone = default_zone }

        it "should work on a regular day" do
          time = Time.zone.local(2017, 1, 2, 10, 0)
          day = time.beginning_of_day
          shown_posts = make_shown_posts(time)
          shown_posts.each do |post|
            expect(post.tagged_at).to be_between(day, day.end_of_day).inclusive
          end

          hidden_posts = make_hidden_posts(time)
          hidden_posts.each do |post|
            expect(post.tagged_at).not_to be_between(day, day.end_of_day).inclusive
          end

          expect(DailyReport.new(time).posts).to match_array(shown_posts)
        end

        it "should work on a daylight change day" do
          time = Time.zone.local(*dst_day_params)
          day = time.beginning_of_day
          # clock goes back; 25 hours in the day
          shown_posts = make_shown_posts(time)
          shown_posts.each do |post|
            expect(post.tagged_at).to be_between(day, day.end_of_day).inclusive
          end

          hidden_posts = make_hidden_posts(time)
          hidden_posts.each do |post|
            expect(post.tagged_at).not_to be_between(day, day.end_of_day).inclusive
          end

          expect(DailyReport.new(time).posts).to match_array(shown_posts)
        end

        def make_shown_posts(time)
          Array.new(24) do |i| # 0 .. 23
            step = time.beginning_of_day + i.hours
            Timecop.freeze(step) { create(:post) }
          end
        end

        def make_hidden_posts(time)
          one = Timecop.freeze(time.beginning_of_day - 1.hour) { create(:post) }
          two = Timecop.freeze(time.end_of_day + 1.hour) { create(:post) }
          [one, two]
        end
      end
    end

    it "does not multiply reply_count" do
      # okay so it kinda multiples it, but it's divided in the view
      now = Time.zone.now
      post = nil
      Timecop.freeze(now - 2.days) do
        post = create(:post)
        create_list(:reply, 2, post: post, user: post.user)
      end
      Timecop.freeze(now) do
        create_list(:reply, 3, post: post, user: post.user)
      end
      report = DailyReport.new(now)
      expect(report.posts.first.reply_count).to eq(5)
    end

    it "calculates today posts with replies timestamp correctly" do
      old = Time.zone
      Time.zone = "Eastern Time (US & Canada)"
      now = Time.zone.now.end_of_day - 1.hour # ensure no issues running near midnight

      post = Timecop.freeze(now) { create(:post) }

      Timecop.freeze(now + 10.minutes) do
        create(:reply, post: post, user: post.user)
      end

      report = DailyReport.new(now)
      expect(report.posts.first.first_updated_at).to be_the_same_time_as(now)
      Time.zone = old
    end

    it "does not perform time zone fuckery" do
      # 2am UTC 5/21 is 10pm EDT 5/20
      mismatch_time = DateTime.new(2020, 5, 21, 2, 30, 0).utc

      # create post unambiguously on 5/20
      post = Timecop.freeze(mismatch_time - 12.hours) do
        create(:post)
      end

      # only the second reply is on 5/21 in EDT
      Timecop.freeze(mismatch_time) { create(:reply, post: post) }
      Timecop.freeze(mismatch_time + 6.hours) { create(:reply, post: post) }

      Time.use_zone('America/New_York') do
        report = DailyReport.new("2020-05-21".to_date)
        posts = report.posts({first_updated_at: :desc})
        expect(posts.to_a.size).to eq(1)
        expect(posts[0].first_updated_at).to be_the_same_time_as(mismatch_time + 6.hours)
      end
    end

    it "returns all necessary posts" do
      report_time = DateTime.new(2020, 4, 4, 3, 0, 0)
      new_today_replies = nil
      new_today_no_replies = nil
      new_yesterday_replies = nil
      new_today_future_replies = nil

      Time.use_zone('UTC') do
        Timecop.freeze(report_time - 1.day) do
          new_yesterday_replies = create(:post)
        end

        Timecop.freeze(report_time) do
          new_today_no_replies = create(:post)
          new_today_replies = create(:post)
          new_today_future_replies = create(:post)
          create(:reply, post: new_yesterday_replies)
        end

        Timecop.freeze(report_time + 1.hour) do
          create(:reply, post: new_today_replies)
        end

        Timecop.freeze(report_time + 2.days) do
          create(:reply, post: new_today_future_replies)
        end

        report = DailyReport.new(report_time.to_date)
        posts = [new_yesterday_replies, new_today_replies, new_today_no_replies, new_today_future_replies]
        expect(report.posts.map(&:id)).to match_array(posts.map(&:id))
      end
    end
  end

  describe "#badge_for" do
    it "is zero when unspecified" do
      expect(DailyReport.badge_for(nil)).to eq(0)
    end

    it "respects timezone" do
      # Hawaii 7pm April 3 UTC 5am April 4
      date = DateTime.new(2020, 4, 4, 5, 0, 0)
      later_date = date + 2.days
      user = create(:user)

      Time.use_zone('UTC') do
        DailyReport.mark_read(user, at_time: date.to_date)
      end

      Timecop.freeze(later_date) do
        Time.use_zone('Hawaii') do
          expect(DailyReport.badge_for(DailyReport.unread_date_for(user))).to eq(1)
        end

        Time.use_zone('UTC') do
          expect(DailyReport.badge_for(DailyReport.unread_date_for(user))).to eq(1)
        end
      end
    end
  end
end
