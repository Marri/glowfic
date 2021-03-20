RSpec.describe Api::V1::BoardSectionsController do
  describe "POST reorder" do
    it "requires login", :show_in_doc do
      post :reorder
      expect(response).to have_http_status(:unauthorized)
      expect(response.json['errors'][0]['message']).to eq("You must be logged in to view that page.")
    end

    it "requires a board you have access to" do
      board = create(:board)
      board_section1 = create(:board_section, board_id: board.id)
      board_section2 = create(:board_section, board_id: board.id)
      expect(board_section1.reload.section_order).to eq(0)
      expect(board_section2.reload.section_order).to eq(1)

      section_ids = [board_section2.id, board_section1.id]

      api_login
      post :reorder, params: { ordered_section_ids: section_ids }
      expect(response).to have_http_status(:forbidden)
      expect(board_section1.reload.section_order).to eq(0)
      expect(board_section2.reload.section_order).to eq(1)
    end

    it "requires a single board" do
      user = create(:user)
      board1 = create(:board, creator: user)
      board2 = create(:board, creator: user)
      board_section1 = create(:board_section, board_id: board1.id)
      board_section2 = create(:board_section, board_id: board2.id)
      board_section3 = create(:board_section, board_id: board2.id)

      expect(board_section1.reload.section_order).to eq(0)
      expect(board_section2.reload.section_order).to eq(0)
      expect(board_section3.reload.section_order).to eq(1)

      section_ids = [board_section3.id, board_section2.id, board_section1.id]
      api_login_as(user)
      post :reorder, params: { ordered_section_ids: section_ids }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.json['errors'][0]['message']).to eq('Sections must be from one board')
      expect(board_section1.reload.section_order).to eq(0)
      expect(board_section2.reload.section_order).to eq(0)
      expect(board_section3.reload.section_order).to eq(1)
    end

    it "requires valid section ids" do
      board = create(:board)
      board_section1 = create(:board_section, board_id: board.id)
      board_section2 = create(:board_section, board_id: board.id)
      expect(board_section1.reload.section_order).to eq(0)
      expect(board_section2.reload.section_order).to eq(1)
      section_ids = [-1]

      api_login_as(board.creator)
      post :reorder, params: { ordered_section_ids: section_ids }
      expect(response).to have_http_status(:not_found)
      expect(response.json['errors'][0]['message']).to eq('Some sections could not be found: -1')
      expect(board_section1.reload.section_order).to eq(0)
      expect(board_section2.reload.section_order).to eq(1)
    end

    it "works for valid changes", :show_in_doc do
      board = create(:board)
      board2 = create(:board, creator: board.creator)
      board_section1 = create(:board_section, board_id: board.id)
      board_section2 = create(:board_section, board_id: board.id)
      board_section3 = create(:board_section, board_id: board.id)
      board_section4 = create(:board_section, board_id: board.id)
      board_section5 = create(:board_section, board_id: board2.id)

      expect(board_section1.reload.section_order).to eq(0)
      expect(board_section2.reload.section_order).to eq(1)
      expect(board_section3.reload.section_order).to eq(2)
      expect(board_section4.reload.section_order).to eq(3)
      expect(board_section5.reload.section_order).to eq(0)

      section_ids = [board_section3.id, board_section1.id, board_section4.id, board_section2.id]

      api_login_as(board.creator)
      post :reorder, params: { ordered_section_ids: section_ids }
      expect(response).to have_http_status(:ok)
      expect(response.json).to eq({'section_ids' => section_ids})
      expect(board_section1.reload.section_order).to eq(1)
      expect(board_section2.reload.section_order).to eq(3)
      expect(board_section3.reload.section_order).to eq(0)
      expect(board_section4.reload.section_order).to eq(2)
      expect(board_section5.reload.section_order).to eq(0)
    end

    it "works when specifying valid subset", :show_in_doc do
      board = create(:board)
      board2 = create(:board, creator: board.creator)
      board_section1 = create(:board_section, board_id: board.id)
      board_section2 = create(:board_section, board_id: board.id)
      board_section3 = create(:board_section, board_id: board.id)
      board_section4 = create(:board_section, board_id: board.id)
      board_section5 = create(:board_section, board_id: board2.id)

      expect(board_section1.reload.section_order).to eq(0)
      expect(board_section2.reload.section_order).to eq(1)
      expect(board_section3.reload.section_order).to eq(2)
      expect(board_section4.reload.section_order).to eq(3)
      expect(board_section5.reload.section_order).to eq(0)

      section_ids = [board_section3.id, board_section1.id]

      api_login_as(board.creator)
      post :reorder, params: { ordered_section_ids: section_ids }
      expect(response).to have_http_status(:ok)
      expect(response.json).to eq({'section_ids' => [board_section3.id, board_section1.id, board_section2.id, board_section4.id]})
      expect(board_section1.reload.section_order).to eq(1)
      expect(board_section2.reload.section_order).to eq(2)
      expect(board_section3.reload.section_order).to eq(0)
      expect(board_section4.reload.section_order).to eq(3)
      expect(board_section5.reload.section_order).to eq(0)
    end
  end
end
