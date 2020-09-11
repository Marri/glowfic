RSpec.describe ApplicationController do
  controller do
    def index
      render json: {zone: Time.zone.name}
    end

    def create
      render json: {}
    end

    def show
      render template: 'sessions/index' # used by check_tos for a GET with a layout
    end
  end

  describe "#set_timezone" do
    let!(:current_zone) { Time.zone.name }

    it "uses the user's time zone within the block" do
      different_zone = ActiveSupport::TimeZone.all.detect { |z| z.name != current_zone }.name
      login_as(create(:user, timezone: different_zone))

      get :index
      expect(response.json['zone']).to eq(different_zone)
    end

    it "succeeds when logged out" do
      get :index
      expect(response.json['zone']).to eq(current_zone)
    end

    it "succeeds when logged in user has no zone set" do
      login_as(create(:user, timezone: nil))
      get :index
      expect(response.json['zone']).to eq(current_zone)
    end
  end

  describe "#show_password_warning" do
    let(:warning) { "Because Marri accidentally made passwords a bit too secure, you must log back in to continue using the site." }
    let(:user) { create(:user) }

    it "shows no warning if logged out" do
      get :index
      expect(flash.now[:error]).not_to eq(warning)
    end

    it "shows no warning for users with salt_uuid" do
      login_as(user)
      expect(user.salt_uuid).not_to be_nil
      get :index
      expect(flash.now[:error]).not_to eq(warning)
    end

    it "shows warning if salt_uuid not set" do
      login_as(user)
      user.update_columns(salt_uuid: nil) # rubocop:disable Rails/SkipsModelValidations
      get :index
      expect(flash.now[:error]).to eq(warning)
    end
  end

  describe "#posts_from_relation" do
    it "gets posts" do
      post = create(:post)
      relation = Post.where.not(id: nil)
      expect(controller.send(:posts_from_relation, relation)).to match_array([post])
    end

    it "will return a blank array if applicable" do
      create(:post)
      relation = Post.where(id: nil)
      expect(controller.send(:posts_from_relation, relation)).to be_blank
    end

    context "with site testing" do
      let(:site_testing) { create(:board, id: Board::ID_SITETESTING) }
      let(:post) { create(:post, board: site_testing) }
      let(:relation) { Post.where(id: post.id) }

      it "skips posts in site testing" do
        expect(relation.no_tests).to be_blank
        expect(controller.send(:posts_from_relation, relation, no_tests: true)).to be_blank
      end

      it "can be made to show site testing posts" do
        expect(controller.send(:posts_from_relation, relation, no_tests: false)).not_to be_blank
      end
    end

    context "with many posts" do
      let(:default_post_ids) { create_list(:post, 26).map(&:id) }
      let(:relation) { Post.where(id: default_post_ids) }

      it "paginates by default" do
        fetched_posts = controller.send(:posts_from_relation, relation)
        expect(fetched_posts.total_pages).to eq(2)
      end

      it "allows pagination to be disabled" do
        fetched_posts = controller.send(:posts_from_relation, relation, with_pagination: false)
        expect(fetched_posts).not_to respond_to(:total_pages)
      end

      it "skips visibility check if there are more than 25 posts" do
        expect_any_instance_of(Post).not_to receive(:visible_to?)
        fetched_posts = controller.send(:posts_from_relation, relation)
        expect(fetched_posts.count).to eq(26) # number when querying the database – actual number returned is 25, due to pagination
      end

      it 'preserves post order with pagination' do
        expect(controller.send(:posts_from_relation, relation.order(tagged_at: :asc)).map(&:id)).to eq(default_post_ids[0..24])
        expect(controller.send(:posts_from_relation, relation.ordered).map(&:id)).to eq(default_post_ids.reverse[0..24])
      end

      it 'preserves post order with pagination disabled' do
        expect(controller.send(:posts_from_relation, relation.order(tagged_at: :asc), with_pagination: false).ids).to eq(default_post_ids)
        expect(controller.send(:posts_from_relation, relation.order(tagged_at: :desc), with_pagination: false).ids).to eq(default_post_ids.reverse)
      end
    end

    it "fetches correct authors, reply counts and content warnings" do
      post1 = create(:post)
      warning1 = create(:content_warning)
      post2 = create(:post, content_warnings: [warning1])
      post2_reply = create(:reply, post: post2)
      warning2 = create(:content_warning)
      post3 = create(:post, content_warnings: [warning1, warning2])
      post3_user2 = create(:user)
      post3_user3 = create(:user)
      create_list(:reply, 25, post: post3, user: post3_user2)
      create_list(:reply, 10, post: post3, user: post3_user3)
      post3.opt_out_of_owed(post3_user3)

      id_list = [post1, post2, post3].map(&:id)
      relation = Post.where(id: id_list).ordered_by_id
      fetched_posts = controller.send(:posts_from_relation, relation)
      expect(fetched_posts.count).to eq(3)
      expect(fetched_posts.map(&:id)).to match_array(id_list)

      fetched1, fetched2, fetched3 = fetched_posts

      expect(fetched_posts.map(&:has_content_warnings?)).to eq([nil, true, true])
      expect(fetched2.content_warnings).to match_array([warning1])
      expect(fetched3.content_warnings).to match_array([warning1, warning2])

      expect(fetched_posts.map(&:reply_count)).to eq([0, 1, 35])

      expect(fetched1.joined_authors).to match_array([post1.user])
      expect(fetched2.joined_authors).to match_array([post2.user, post2_reply.user])
      expect(fetched3.joined_authors).to match_array([post3.user, post3_user2, post3_user3])
      expect(fetched1.joined_author_ids).to match_array([post1.user_id])
      expect(fetched2.joined_author_ids).to match_array([post2.user_id, post2_reply.user_id])
      expect(fetched3.joined_author_ids).to match_array([post3.user_id, post3_user2.id, post3_user3.id])
    end

    context "when logged in" do
      let(:user) { create(:user) }

      before(:each) { login_as(user) }

      it "returns empty array if no visible posts" do
        hidden_post = create(:post, privacy: :private)
        expect(hidden_post).not_to be_visible_to(user)

        relation = Post.where(id: hidden_post.id)
        fetched_posts = controller.send(:posts_from_relation, relation)
        expect(fetched_posts).to be_empty
      end

      it "filters array if mixed visible and not visible posts" do
        hidden_post = create(:post, privacy: :private)
        public_post = create(:post, privacy: :public)
        own_post = create(:post, user: user, privacy: :public)

        relation = Post.where(id: [hidden_post.id, public_post.id, own_post.id])
        fetched_posts = controller.send(:posts_from_relation, relation)
        expect(fetched_posts).to match_array([public_post, own_post])
      end

      it "sets opened_ids and unread_ids properly" do
        other_user = create(:user)
        time = Time.zone.now - 5.minutes
        unopened, partread, read1, read2, hidden_unread, hidden_partread = posts = Timecop.freeze(time) do
          create(:post)
          unopened = create(:post)
          partread = create(:post)
          read1 = create(:post)
          read2 = create(:post)
          hidden_unread = create(:post)
          hidden_partread = create(:post)

          partread.mark_read(user)
          read1.mark_read(user)
          hidden_partread.mark_read(user)

          [unopened, partread, read1, read2, hidden_unread, hidden_partread]
        end

        Timecop.freeze(time + 1.minute) do
          create(:reply, post: unopened)
          create(:reply, post: partread)
          create(:reply, post: read2)
          create(:reply, post: hidden_partread)

          read2.mark_read(user)
          partread.reload
          partread.mark_read(other_user)
        end

        hidden_unread.ignore(user)
        hidden_partread.ignore(user)

        relation = Post.where(id: posts.map(&:id))
        fetched_posts = controller.send(:posts_from_relation, relation)
        expect(fetched_posts).to match_array(posts)
        expect(assigns(:opened_ids)).to match_array([partread, read1, read2, hidden_partread].map(&:id))
        expect(assigns(:unread_ids)).to match_array([partread, hidden_partread].map(&:id))
      end

      it "can calculate unread count" do
        user = create(:user)
        other_user = create(:user)

        unread_post = create(:post, num_replies: 3)
        read_post = create(:post, num_replies: 2)
        one_unread = create(:post)
        two_unread = create(:post, num_replies: 1)

        read_post.mark_read(user)
        one_unread.mark_read(user)
        one_unread.reload
        one_unread.mark_read(other_user)
        two_unread.mark_read(user)

        create(:reply, post: one_unread)
        create_list(:reply, 2, post: two_unread)

        two_unread.reload
        two_unread.mark_read(other_user)

        posts = [unread_post, read_post, one_unread, two_unread]
        relation = Post.where(id: posts.map(&:id))
        login_as(user)
        fetched_posts = controller.send(:posts_from_relation, relation, with_unread: true)
        expect(fetched_posts).to match_array(posts)
        expect(assigns(:opened_ids)).to match_array([read_post.id, one_unread.id, two_unread.id])
        expect(assigns(:unread_ids)).to match_array([one_unread.id, two_unread.id])
        expect(assigns(:unread_counts)).to eq({
          one_unread.id => 1,
          two_unread.id => 2,
        })
      end
    end

    context "when logged out" do
      let!(:hidden_post) { create(:post, privacy: :private) }

      it "returns empty array if no visible posts" do
        relation = Post.where(id: hidden_post.id)
        fetched_posts = controller.send(:posts_from_relation, relation)
        expect(fetched_posts).to be_empty
      end

      it "filters array if mixed visible and not visible posts" do
        public_post = create(:post, privacy: :public)
        conste_post = create(:post, privacy: :registered)

        relation = Post.where(id: [hidden_post.id, public_post.id, conste_post.id])
        fetched_posts = controller.send(:posts_from_relation, relation)
        expect(fetched_posts).to match_array([public_post])
      end
    end

    it 'preserves post order' do
      posts = create_list(:post, 4)
      expect(controller.send(:posts_from_relation, Post.all.order(tagged_at: :asc))).to eq(posts)
      expect(controller.send(:posts_from_relation, Post.all.ordered)).to eq(posts.reverse)
    end

    it "uses an accurate custom post_count with joins and groups" do
      create(:post, privacy: :private) # hidden
      replyless = create(:post)
      replyful = create(:post)
      create_list(:reply, 2, post: replyful)

      login
      relation = Post.select("posts.*").left_joins(:replies).group("posts.id")
      result = controller.send(:posts_from_relation, relation, max: true)
      expect(result.to_a).to match_array([replyless, replyful])
      expect(result.total_entries).to eq(2)
    end

    it "has more tests" do
      skip
    end
  end

  describe "#require_glowfic_domain" do
    it "redirects on valid requests" do
      ENV['DOMAIN_NAME'] ||= 'domaintest.host'
      get :index, params: {force_domain: true}
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to('https://domaintest.host/anonymous?force_domain=true')
    end

    it "does not redirect on post requests" do
      post :create, params: {force_domain: true}
      expect(response).to have_http_status(:ok)
    end

    it "does not redirect unless forced" do
      get :index
      expect(response).to have_http_status(:ok)
    end

    it "does not redirect API requests" do
      get :index, params: {force_domain: true}, xhr: true
      expect(response).to have_http_status(:ok)
    end

    it "does not redirect glowfic.com requests" do
      request.host = 'glowfic.com'
      get :index, params: {force_domain: true}
      expect(response).to have_http_status(:ok)
    end

    it "does not redirect staging requests" do
      request.host = 'glowfic-staging.herokuapp.com'
      get :index, params: {force_domain: true}
      expect(response).to have_http_status(:ok)
    end
  end

  describe "#page_view" do
    context "when logged out" do
      it "works by default" do
        expect(controller.send(:page_view)).to eq('icon')
      end

      it "can be overridden with a parameter" do
        controller.params[:view] = 'list'
        expect(session[:view]).to be_nil
        expect(controller.send(:page_view)).to eq('list')
        expect(session[:view]).to eq('list')
      end

      it "uses session variable if it exists" do
        session[:view] = 'list'
        expect(controller.send(:page_view)).to eq('list')
      end
    end

    context "when logged in" do
      let(:user) { create(:user, default_view: 'list') }

      it "works by default" do
        login
        expect(controller.send(:page_view)).to eq('icon')
      end

      it "uses account default if different" do
        login_as(user)
        expect(controller.send(:page_view)).to eq('list')
      end

      it "is not overridden by session" do
        # also does not modify user default
        login_as(user)
        session[:view] = 'icon'
        expect(controller.send(:page_view)).to eq('list')
        expect(user.reload.default_view).to eq('list')
      end

      it "can be overridden by params" do
        # also does not modify user default
        login_as(user)
        controller.params[:view] = 'icon'
        expect(controller.send(:page_view)).to eq('icon')
        expect(user.reload.default_view).to eq('list')
      end
    end
  end

  describe "#check_tos" do
    render_views

    it "shows TOS prompt to logged in users" do
      user = create(:user, tos_version: nil)
      login_as(user)
      get :show, params: {force_tos: true, id: 1}
      expect(response).to render_template('about/accept_tos')
    end

    it "shows TOS prompt to logged out users" do
      get :show, params: {force_tos: true, id: 1}
      expect(response).to render_template(partial: 'about/_accept_tos')
    end
  end

  describe "#check_forced_logout" do
    controller do
      def index
        render json: {logged_in: current_user.present?}
      end
    end

    let(:user) { create(:user) }

    before(:each) { login_as(user) }

    it "does not log out unsuspended undeleted" do
      get :index
      expect(response.json['logged_in']).to be(true)
    end

    it "logs out suspended" do
      user.update!(role_id: Permissible::SUSPENDED)
      get :index
      expect(response.json['logged_in']).to eq(false)
    end

    it "logs out deleted" do
      user.update!(deleted: true)
      get :index
      expect(response.json['logged_in']).to eq(false)
    end
  end

  describe "#check_permanent_user" do
    it "sets the user from cookie" do
      current_zone = Time.zone.name
      different_zone = ActiveSupport::TimeZone.all.detect { |z| z.name != current_zone }.name
      user = create(:user, timezone: different_zone)
      cookies.signed[:user_id] = user.id

      get :index
      expect(response.json['zone']).to eq(different_zone)
    end
  end
end
