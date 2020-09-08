RSpec.describe ReportsController do
  describe "GET index" do
    it "succeeds when logged out" do
      get :index
      expect(response).to have_http_status(200)
    end

    it "succeeds when logged in" do
      login
      get :index
      expect(response).to have_http_status(200)
    end
  end

  describe "GET show" do
    let(:user) { create(:user) }

    it "requires valid type" do
      get :show, params: { id: -1 }
      expect(response).to redirect_to(reports_url)
      expect(flash[:error]).to eq("Could not identify the type of report.")
    end

    it "succeeds with daily" do
      get :show, params: { id: 'daily' }
      expect(response).to have_http_status(200)
    end

    it "sets variables with logged in daily" do
      post = create(:post)
      post.mark_read(user)
      time = post.last_read(user)
      login_as(user)
      get :show, params: { id: 'daily' }
      expect(response).to have_http_status(200)
      expect(assigns(:board_views)).to be_empty
      expect(assigns(:opened_ids)).to match_array([post.id])
      expect(assigns(:opened_posts).length).to eq(1)
      expect(assigns(:opened_posts).first.read_at).to be_the_same_time_as(time)
    end

    it "handles invalid day argument" do
      get :show, params: { id: 'daily', day: 'asdf' }
      expect(response).to have_http_status(200)
    end

    it "handles out of range argument" do
      get :show, params: { id: 'daily', day: '2018-28-10' }
      expect(response).to have_http_status(200)
    end

    it "sorts by timestamp" do
      today = DateTime.now.utc.beginning_of_day
      post1 = Timecop.freeze(today) { create(:post, subject: 'aaa') }
      post2 = Timecop.freeze(today + 1.hour) { create(:post, subject: 'bbb') }
      user = create(:user, timezone: 'UTC')
      login_as(user)
      get :show, params: { id: 'daily', day: today.to_date.to_s }
      expect(assigns(:posts)[0].id).to eq(post2.id)
      expect(assigns(:posts)[1].id).to eq(post1.id)
    end

    it "sorts by subject" do
      today = DateTime.now.utc.beginning_of_day
      post1 = Timecop.freeze(today) { create(:post, subject: 'aaa') }
      post2 = Timecop.freeze(today + 1.hour) { create(:post, subject: 'bbb') }
      user = create(:user, timezone: 'UTC')
      login_as(user)
      get :show, params: { id: 'daily', day: today.to_date.to_s, sort: 'subject' }
      expect(assigns(:posts)[0].id).to eq(post1.id)
      expect(assigns(:posts)[1].id).to eq(post2.id)
    end

    it "sorts by continuity" do
      today = DateTime.now.utc.beginning_of_day
      board1 = create(:board, name: 'cc')
      board2 = create(:board, name: 'dd')
      post1 = Timecop.freeze(today) { create(:post, board: board1) }
      post2 = Timecop.freeze(today + 2.hours) { create(:post, board: board1) }
      post3 = Timecop.freeze(today) { create(:post, board: board2) }
      post4 = Timecop.freeze(today + 1.hour) { create(:post, board: board2) }
      user = create(:user, timezone: 'UTC')
      login_as(user)
      get :show, params: { id: 'daily', day: today.to_date.to_s, sort: 'continuity' }
      expect(assigns(:posts).map(&:id)).to eq([post2, post1, post4, post3].map(&:id))
    end

    it "succeeds with monthly" do
      get :show, params: { id: 'monthly' }
      expect(response).to have_http_status(200)
    end

    it "succeeds with deleted user" do
      valid = create(:post)
      invalid = create(:post, user: create(:user, deleted: true))
      get :show, params: { id: 'daily' }
      valid_report = assigns(:posts).detect { |p| p.id == valid.id }
      invalid_report = assigns(:posts).detect { |p| p.id == invalid.id }
      expect(valid_report.last_user_deleted).to eq(false)
      expect(invalid_report.last_user_deleted).to eq(true)
    end

    it "ignores not-new when specified" do
      today = DateTime.now.utc.beginning_of_day + 1.hour
      valid = Timecop.freeze(today) { create(:post) }
      invalid = Timecop.freeze(today - 2.days) { create(:post) }
      Timecop.freeze(today) { create(:reply, post: invalid) }
      user = create(:user, timezone: 'UTC')
      login_as(user)
      get :show, params: { id: 'daily', day: today.to_date.to_s, new_today: 'true' }
      expect(assigns(:posts).map(&:id)).to eq([valid.id])
    end

    context "with views" do
      render_views

      it "works" do
        create_list(:post, 3)
        Post.last.user.update!(moiety: 'abcdef')
        create(:post, num_replies: 4, created_at: 2.days.ago)
        get :show, params: { id: 'daily' }
      end

      it "works with logged in" do
        DailyReport.mark_read(user, at_time: 3.days.ago.to_date)
        create(:post_view, user: user)
        login_as(user)
        get :show, params: { id: 'daily' }
      end
    end

    context "reading" do
      ["Hawaii", "UTC", "Auckland", nil].each do |place|
        context "in #{place}" do
          let(:user) { create(:user, timezone: place) }

          # the user's report_view.read_at should be set in their relevant timezone, since that's what will occur in the application
          # the user's report_view.read_at should be read as a date *in their timezone*, since again, that's what happens in the application

          it "does not mark read for today's unfinished report" do
            expect(user.report_view).to be_nil
            login_as(user)
            get :show, params: { id: 'daily' }
            expect(user.reload.report_view).to be_nil
          end

          it "marks read for previous days" do
            expect(user.report_view).to be_nil
            login_as(user)
            viewed_time = 2.days.ago
            expect_time = viewed_time

            get :show, params: { id: 'daily', day: viewed_time.to_date.to_s }

            user.reload
            expect(user.report_view).not_to be_nil
            expect(user.report_view.read_at.in_time_zone(place).to_date).to eq(expect_time.to_date)
          end

          it "does not mark read for ignoring users" do
            user.update!(ignore_unread_daily_report: true)
            expect(user.report_view).to be_nil
            login_as(user)
            get :show, params: { id: 'daily', day: 2.days.ago.to_date.to_s }
            expect(user.report_view).to be_nil
          end

          it "marks read for previous days when already read once" do
            expect(user.report_view).to be_nil

            before_time = 3.days.ago
            viewed_time = 2.days.ago
            expect_time = viewed_time
            Time.use_zone(place) do
              DailyReport.mark_read(user, at_time: before_time.to_date)
            end

            login_as(user)
            get :show, params: { id: 'daily', day: viewed_time.to_date.to_s }

            user.reload
            expect(user.report_view).not_to be_nil
            expect(user.report_view.read_at.in_time_zone(place).to_date).to eq(expect_time.to_date)
          end

          it "does not mark read if you've read more recently" do
            expect(user.report_view).to be_nil

            before_time = 2.days.ago
            viewed_time = 3.days.ago
            expect_time = before_time
            Time.use_zone(place) do
              DailyReport.mark_read(user, at_time: before_time.to_date)
            end

            login_as(user)
            get :show, params: { id: 'daily', day: viewed_time.to_date.to_s }

            user.reload
            expect(user.report_view).not_to be_nil
            expect(user.report_view.read_at.in_time_zone(place).to_date).to eq(expect_time.to_date)
          end
        end
      end
    end
  end
end
