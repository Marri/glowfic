RSpec.describe Api::ApiController do
  controller do
    before_action :login_required, only: :show

    def index
      render json: {results: [1]} and return unless logged_in?
      render json: {results: [1, 2]}
    end

    def show
      render json: {results: [1, 2, 3]}
    end
  end

  describe "token handling" do
    context "with login_required" do
      it "displays an error if an invalid token is provided" do
        request.headers.merge({'Authorization': "Bearer definitely-invalid"})
        get :show, params: {id: 1}
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.json['errors'][0]['message']).to eq("Authorization token is not valid.")
      end

      it "displays an error if an expired token is provided" do
        cur_time = Time.zone.now
        Timecop.freeze(cur_time) { api_login }
        Timecop.freeze(cur_time + Authentication::EXPIRY + 3.days) do
          get :show, params: {id: 1}
          expect(response).to have_http_status(:unauthorized)
          expect(response.json['errors'][0]['message']).to eq("Authorization token has expired.")
        end
      end

      it "works when valid token is provided" do
        api_login
        get :show, params: {id: 1}
        expect(response).to have_http_status(:ok)
        expect(response.json['results'].size).to eq(3)
      end
    end

    context "without login_required but with mixed data" do
      it "displays an error if an invalid token is provided" do
        request.headers.merge({'Authorization': "Bearer definitely-invalid"})
        get :index
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.json['errors'][0]['message']).to eq("Authorization token is not valid.")
      end

      it "displays an error if an expired token is provided" do
        cur_time = Time.zone.now
        Timecop.freeze(cur_time) { api_login }
        Timecop.freeze(cur_time + Authentication::EXPIRY + 3.days) do
          get :index
          expect(response).to have_http_status(:unauthorized)
          expect(response.json['errors'][0]['message']).to eq("Authorization token has expired.")
        end
      end

      it "displays some data when logged out" do
        get :index
        expect(response).to have_http_status(:ok)
        expect(response.json['results'].size).to eq(1)
      end

      it "displays all data when logged in" do
        api_login
        get :index
        expect(response).to have_http_status(:ok)
        expect(response.json['results'].size).to eq(2)
      end
    end
  end
end
