RSpec.describe NotificationsController do
  describe "GET index" do
    let(:user) { create(:user) }

    it "requires login" do
      get :index
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    context "with views" do
      render_views
      it "works" do
        notifications = create_list(:notification, 3, user: user, notification_type: :new_favorite_post)
        notifications += create_list(:notification, 2, user: user, notification_type: :joined_favorite_post)
        notifications += create_list(:notification, 2, user: user, notification_type: :import_success)
        notifications << create(:notification, user: user, notification_type: :import_fail)
        post_ids = notifications.map(&:post_id)
        notifications << create(:error_notification, user: user)
        create_list(:notification, 3)
        login_as(user)
        get :index
        expect(assigns(:notifications).map(&:id)).to match_array(notifications.map(&:id))
        expect(assigns(:posts).keys).to match_array(post_ids)
        expect(flash[:error]).not_to be_present
      end
    end

    it "paginates" do
      create_list(:notification, 3, user: user)
      notifications = create_list(:notification, 22, user: user)
      notifications += create_list(:error_notification, 3, user: user)
      post_ids = notifications.map(&:post_id).reject(&:blank?)
      login_as(user)
      get :index
      expect(assigns(:notifications).map(&:id)).to match_array(notifications.map(&:id))
      expect(assigns(:posts).keys).to match_array(post_ids)
      expect(flash[:error]).not_to be_present
    end
  end

  describe "POST mark" do
    it "requires login" do
      post :mark
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq("You must be logged in to view that page.")
    end

    it "requires valid action" do
      login
      post :mark
      expect(response).to redirect_to(notifications_url)
      expect(flash[:error]).to eq("Could not perform unknown action.")
    end

    context "marking unread" do
      let(:notification) { create(:notification, unread: false) }

      it "handles invalid notification ids" do
        login
        expect_any_instance_of(Notification).not_to receive(:update)
        post :mark, params: { marked_ids: ['nope', -1, '0'], commit: "Mark Unread" }
      end

      it "does not work the wrong user" do
        login
        post :mark, params: { marked_ids: [notification.id.to_s], commit: "Mark Unread" }
        expect(notification.reload.unread).to eq(false)
      end

      it "works unread for user" do
        notification.update!(unread: true)
        login_as(notification.user)
        post :mark, params: { marked_ids: [notification.id.to_s], commit: "Mark Unread" }
        expect(notification.reload.unread).to eq(true)
      end

      it "works read for user" do
        login_as(notification.user)
        post :mark, params: { marked_ids: [notification.id.to_s], commit: "Mark Unread" }
        expect(notification.reload.unread).to eq(true)
      end
    end

    context "marking read" do
      let(:notification) { create(:notification, unread: true) }

      it "handles invalid notification ids" do
        login
        expect_any_instance_of(Notification).not_to receive(:update)
        post :mark, params: { marked_ids: ['nope', -1, '0'], commit: "Mark Read" }
      end

      it "does not work for the wrong user" do
        login
        post :mark, params: { marked_ids: [notification.id.to_s], commit: "Mark Read" }
        expect(notification.reload.unread).to eq(true)
      end

      it "works unread for user" do
        login_as(notification.user)
        post :mark, params: { marked_ids: [notification.id.to_s], commit: "Mark Read" }
        expect(notification.reload.unread).to eq(false)
      end

      it "works read for user" do
        notification.update!(unread: false)
        login_as(notification.user)
        post :mark, params: { marked_ids: [notification.id.to_s], commit: "Mark Read" }
        expect(notification.reload.unread).to eq(false)
      end
    end

    context "deleting" do
      let(:notification) { create(:notification) }

      it "handles invalid notification ids" do
        login
        expect_any_instance_of(Notification).not_to receive(:update)
        post :mark, params: { marked_ids: ['nope', -1, '0'], commit: "Delete" }
      end

      it "does not work for other users" do
        login
        post :mark, params: { marked_ids: [notification.id.to_s], commit: "Delete" }
        expect(Notification.find_by(id: notification.id)).to be_present
      end

      it "works for user" do
        login_as(notification.user)
        post :mark, params: { marked_ids: [notification.id.to_s], commit: "Delete" }
        expect(Notification.find_by(id: notification.id)).not_to be_present
      end
    end
  end
end
