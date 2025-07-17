require 'rails_helper'

RSpec.describe MemosController, type: :controller do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:memo) { create(:memo, user: user) }

  before do
    sign_in user
  end

  describe "POST #toggle_visibility" do
    context "when user is owner" do
      it "toggles visibility from private to public" do
        memo.update(visibility: :private_memo)
        post :toggle_visibility, params: { id: memo.id }
        expect(memo.reload.public_memo?).to be true
      end

      it "toggles visibility from public to private" do
        memo.update(visibility: :public_memo)
        post :toggle_visibility, params: { id: memo.id }
        expect(memo.reload.private_memo?).to be true
      end

      it "returns success response" do
        post :toggle_visibility, params: { id: memo.id }
        expect(response).to redirect_to(memo_path(memo))
      end

      context "when update fails" do
        before do
          allow_any_instance_of(Memo).to receive(:update).and_return(false)
          post :toggle_visibility, params: { id: memo.id }
        end

        it "shows error message" do
          expect(flash[:alert]).to be_present
        end

        it "redirects to memo page" do
          expect(response).to redirect_to(memo_path(memo))
        end
      end
    end

    context "when user is not owner" do
      before do
        sign_in other_user
        post :toggle_visibility, params: { id: memo.id }
      end

      it "redirects to root path" do
        expect(response).to redirect_to(root_path)
      end

      it "shows error message" do
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "POST #share" do
    context "when user is owner" do
      it "creates share with target user" do
        expect {
          post :share, params: { id: memo.id, user_id: other_user.id }
        }.to change(memo.shares, :count).by(1)
      end

      it "redirects to memo page with success message" do
        post :share, params: { id: memo.id, user_id: other_user.id }
        expect(response).to redirect_to(memo_path(memo))
        expect(flash[:notice]).to be_present
      end

      context "with invalid parameters" do
        it "rejects sharing to non-existent user" do
          post :share, params: { id: memo.id, user_id: 999 }
          expect(response).to redirect_to(memo_path(memo))
          expect(flash[:alert]).to be_present
        end

        it "rejects self-sharing" do
          post :share, params: { id: memo.id, user_id: user.id }
          expect(response).to redirect_to(memo_path(memo))
          expect(flash[:alert]).to be_present
        end

        it "rejects duplicate sharing" do
          create(:share, memo: memo, user: other_user)
          post :share, params: { id: memo.id, user_id: other_user.id }
          expect(response).to redirect_to(memo_path(memo))
          expect(flash[:alert]).to be_present
        end
      end

      context "when save fails" do
        before do
          allow_any_instance_of(Share).to receive(:save).and_return(false)
          post :share, params: { id: memo.id, user_id: other_user.id }
        end

        it "shows error message" do
          expect(flash[:alert]).to be_present
        end

        it "redirects to memo page" do
          expect(response).to redirect_to(memo_path(memo))
        end
      end
    end

    context "when user is not owner" do
      before do
        sign_in other_user
        post :share, params: { id: memo.id, user_id: create(:user).id }
      end

      it "redirects to root path" do
        expect(response).to redirect_to(root_path)
      end

      it "shows error message" do
        expect(flash[:alert]).to be_present
      end
    end
  end

RSpec.describe MemosController, type: :controller do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:memo) { create(:memo, user: user) }

  before { sign_in user }

  describe "GET #index" do
    let!(:public_memo) { create(:memo, :public) }
    let!(:private_memo) { create(:memo) }

    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end

    it "includes user's private memos" do
      get :index
      expect(assigns(:memos)).to include(memo)
    end

    it "includes public memos" do
      get :index
      expect(assigns(:memos)).to include(public_memo)
    end

    it "does not include other users' private memos" do
      other_memo = create(:memo, user: other_user)
      get :index
      expect(assigns(:memos)).not_to include(other_memo)
    end

    context "when unauthenticated" do
      before { sign_out user }

      it "redirects to login page" do
        get :index
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "POST #create" do
    context "with valid params" do
      it "creates a new memo" do
        expect {
          post :create, params: { memo: attributes_for(:memo) }
        }.to change(Memo, :count).by(1)
      end

      it "creates memo with tags" do
        expect {
          post :create, params: { memo: attributes_for(:memo, :with_tags) }
        }.to change(MemoTag, :count).by(3)
      end
    end

    context "with invalid params" do
      it "does not create memo" do
        expect {
          post :create, params: { memo: { title: '' } }
        }.not_to change(Memo, :count)
      end

      it "renders error messages" do
        post :create, params: { memo: { title: '' } }
        expect(response.body).to include("can't be blank")
      end

      it "handles too long title" do
        post :create, params: { memo: { title: 'a' * 256 } }
        expect(response.body).to include("is too long")
      end
    end
  end

  describe "PATCH #update" do
    context "when unauthorized" do
      before { sign_in other_user }

      it "returns forbidden status" do
        patch :update, params: { id: memo.id, memo: { title: 'New title' } }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with valid params" do
      it "updates memo" do
        patch :update, params: { id: memo.id, memo: { title: 'New title' } }
        expect(memo.reload.title).to eq('New title')
      end

      it "updates memo tags" do
        patch :update, params: { id: memo.id, memo: { tag_list: 'tag1,tag2' } }
        expect(memo.reload.tags.count).to eq(2)
      end
    end

    context "with invalid params" do
      it "does not update memo" do
        patch :update, params: { id: memo.id, memo: { title: '' } }
        expect(memo.reload.title).not_to be_empty
      end
    end
  end

  describe "GET #index tag filtering" do
    let!(:memo1) { create(:memo, tag_list: ["ruby"]) }
    let!(:memo2) { create(:memo, tag_list: ["rails"]) }
    let!(:memo3) { create(:memo, tag_list: ["a" * 50]) }
    let!(:memo4) { create(:memo, tag_list: ["ruby@rails"]) }
    let!(:memo5) { create(:memo, tag_list: ["ruby", "ruby"]) }

    it "filters memos by tag" do
      get :index, params: { tag: "ruby" }
      expect(assigns(:memos)).to include(memo1)
      expect(assigns(:memos)).not_to include(memo2)
    end

    it "handles maximum length tags" do
      get :index, params: { tag: "a" * 50 }
      expect(assigns(:memos)).to include(memo3)
    end

    it "handles special characters in tags" do
      get :index, params: { tag: "ruby@rails" }
      expect(assigns(:memos)).to include(memo4)
    end

    it "deduplicates identical tags" do
      get :index, params: { tag: "ruby" }
      expect(memo5.tags.count).to eq(1)
    end

    it "handles empty tag parameter" do
      get :index, params: { tag: "" }
      expect(assigns(:memos).count).to eq(5)
    end
  end

  describe "GET #search" do
    let!(:memo1) { create(:memo, title: 'Ruby on Rails', tag_list: 'programming') }
    let!(:memo2) { create(:memo, title: 'React JS', tag_list: 'frontend') }
    let!(:memo3) { create(:memo, title: 'Ruby basics', tag_list: 'programming,beginner') }

    it "returns matching memos by title" do
      get :search, params: { q: 'Ruby' }
      expect(assigns(:memos)).to contain_exactly(memo1, memo3)
      expect(assigns(:memos)).not_to include(memo2)
    end

    it "returns empty when no match" do
      get :search, params: { q: 'Python' }
      expect(assigns(:memos)).to be_empty
    end

    it "returns memos matching tags" do
      get :search, params: { tag: 'programming' }
      expect(assigns(:memos)).to contain_exactly(memo1, memo3)
    end

    it "returns memos matching title and tags" do
      get :search, params: { q: 'Ruby', tag: 'beginner' }
      expect(assigns(:memos)).to contain_exactly(memo3)
    end

    it "handles empty search params" do
      get :search, params: {}
      expect(assigns(:memos)).to be_empty
    end
  end

  describe "GET #index pagination" do
    before { create_list(:memo, 15, user: user) }

    it "returns first page with default per_page" do
      get :index
      expect(assigns(:memos).count).to eq(10)
    end

    it "returns second page when requested" do
      get :index, params: { page: 2 }
      expect(assigns(:memos).count).to eq(5)
    end

    it "respects per_page parameter" do
      get :index, params: { per_page: 5 }
      expect(assigns(:memos).count).to eq(5)
    end
  end

  describe "GET #index sorting" do
    let!(:old_memo) { create(:memo, user: user, created_at: 1.week.ago) }
    let!(:new_memo) { create(:memo, user: user, created_at: 1.day.ago) }

    it "sorts by newest first by default" do
      get :index
      expect(assigns(:memos).first).to eq(new_memo)
    end

    it "sorts by oldest when requested" do
      get :index, params: { sort: 'oldest' }
      expect(assigns(:memos).first).to eq(old_memo)
    end
  end

  describe "PATCH #update visibility" do
    it "changes memo to public" do
      patch :update, params: { id: memo.id, memo: { public: true } }
      expect(memo.reload.public).to be true
    end

    it "changes memo to private" do
      memo.update!(public: true)
      patch :update, params: { id: memo.id, memo: { public: false } }
      expect(memo.reload.public).to be false
    end
  end

  describe "DELETE #destroy" do
    let!(:memo) { create(:memo, user: user) }

    it "deletes the memo" do
      expect {
        delete :destroy, params: { id: memo.id }
      }.to change(Memo, :count).by(-1)
    end

    it "redirects to memos index" do
      delete :destroy, params: { id: memo.id }
      expect(response).to redirect_to(memos_path)
    end

    context "when unauthorized" do
      before { sign_in other_user }

      it "returns forbidden status" do
        delete :destroy, params: { id: memo.id }
        expect(response).to have_http_status(:forbidden)
      end

      it "does not delete the memo" do
        expect {
          delete :destroy, params: { id: memo.id }
        }.not_to change(Memo, :count)
      end
    end

    context "with non-existent memo" do
      it "returns not found" do
        delete :destroy, params: { id: 9999 }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET #show" do
    context "when memo not found" do
      it "returns not found" do
        get :show, params: { id: 9999 }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthorized" do
      let(:private_memo) { create(:memo, user: other_user) }

      it "returns forbidden status" do
        get :show, params: { id: private_memo.id }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST #add_memo" do
    let(:source_memo) { create(:memo, user: other_user, visibility: :public_memo) }

    context "when unauthorized" do
      let(:private_memo) { create(:memo, user: other_user) }

      it "redirects with alert" do
        post :add_memo, params: { id: private_memo.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when save fails" do
      before do
        allow_any_instance_of(Memo).to receive(:save).and_return(false)
      end

      it "redirects with error message" do
        post :add_memo, params: { id: source_memo.id }
        expect(response).to redirect_to(memo_path(source_memo))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "GET #latest" do
    context "when unauthenticated" do
      before { sign_out user }

      it "redirects to login page" do
        get :latest
        expect(response).to redirect_to(auth_login_path)
      end
    end

    context "when current_user_model is nil" do
      before do
        allow(controller).to receive(:current_user_model).and_return(nil)
      end

      it "redirects with error message" do
        get :latest
        expect(response).to redirect_to(auth_login_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "GET #public_memos" do
    let!(:public_memo) { create(:memo, :public) }
    let!(:private_memo) { create(:memo) }
    let!(:tagged_public_memo) { create(:memo, :public, tag_list: "ruby") }

    it "returns http success" do
      get :public_memos
      expect(response).to have_http_status(:success)
    end

    it "includes public memos" do
      get :public_memos
      expect(assigns(:memos)).to include(public_memo)
    end

    it "does not include private memos" do
      get :public_memos
      expect(assigns(:memos)).not_to include(private_memo)
    end

    it "filters memos by tag" do
      get :public_memos, params: { tags: ["ruby"] }
      expect(assigns(:memos)).to include(tagged_public_memo)
      expect(assigns(:memos)).not_to include(public_memo)
    end

    it "searches memos by title" do
      ruby_memo = create(:memo, :public, title: "Ruby on Rails")
      get :public_memos, params: { word: "Ruby" }
      expect(assigns(:memos)).to include(ruby_memo)
    end

    it "sorts memos by newest first by default" do
      old_memo = create(:memo, :public, created_at: 1.week.ago)
      new_memo = create(:memo, :public, created_at: 1.day.ago)
      get :public_memos
      expect(assigns(:memos).first).to eq(new_memo)
    end

    it "paginates results" do
      create_list(:memo, 15, :public)
      get :public_memos, params: { page: 2 }
      expect(assigns(:memos).count).to be <= 10
    end

    context "with invalid tag parameter" do
      it "handles malformed tag parameter" do
        get :public_memos, params: { tags: { invalid: "data" } }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET #shared_memos" do
    let!(:shared_memo) { create(:memo, user: other_user) }
    let!(:unshared_memo) { create(:memo, user: other_user) }
    let!(:tagged_shared_memo) { create(:memo, user: other_user, tag_list: "rails") }
    
    before do
      create(:share, memo: shared_memo, user: user)
      create(:share, memo: tagged_shared_memo, user: user)
    end

    it "returns http success" do
      get :shared_memos
      expect(response).to have_http_status(:success)
    end

    it "includes shared memos" do
      get :shared_memos
      expect(assigns(:memos)).to include(shared_memo)
    end

    it "does not include unshared memos" do
      get :shared_memos
      expect(assigns(:memos)).not_to include(unshared_memo)
    end

    it "filters memos by tag" do
      get :shared_memos, params: { tags: ["rails"] }
      expect(assigns(:memos)).to include(tagged_shared_memo)
      expect(assigns(:memos)).not_to include(shared_memo)
    end

    it "searches memos by title" do
      rails_memo = create(:memo, user: other_user, title: "Rails Tutorial")
      create(:share, memo: rails_memo, user: user)
      get :shared_memos, params: { word: "Rails" }
      expect(assigns(:memos)).to include(rails_memo)
    end

    it "sorts memos by newest first by default" do
      old_memo = create(:memo, user: other_user, created_at: 1.week.ago)
      new_memo = create(:memo, user: other_user, created_at: 1.day.ago)
      create(:share, memo: old_memo, user: user)
      create(:share, memo: new_memo, user: user)
      get :shared_memos
      expect(assigns(:memos).first).to eq(new_memo)
    end

    it "paginates results" do
      15.times do
        memo = create(:memo, user: other_user)
        create(:share, memo: memo, user: user)
      end
      get :shared_memos, params: { page: 2 }
      expect(assigns(:memos).count).to be <= 10
    end

    context "with invalid tag parameter" do
      it "handles malformed tag parameter" do
        get :shared_memos, params: { tags: { invalid: "data" } }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "Turbo Stream responses" do
    describe "POST #create" do
      it "responds with turbo stream when successful" do
        post :create, params: { memo: attributes_for(:memo), format: :turbo_stream }
        expect(response.media_type).to eq Mime[:turbo_stream]
      end

      it "responds with turbo stream and error when invalid" do
        post :create, params: { memo: { title: '' }, format: :turbo_stream }
        expect(response.media_type).to eq Mime[:turbo_stream]
        expect(response.body).to include("can't be blank")
      end
    end

    describe "PATCH #update" do
      it "responds with turbo stream when successful" do
        patch :update, params: { id: memo.id, memo: { title: 'Updated' }, format: :turbo_stream }
        expect(response.media_type).to eq Mime[:turbo_stream]
      end

      it "responds with turbo stream and error when invalid" do
        patch :update, params: { id: memo.id, memo: { title: '' }, format: :turbo_stream }
        expect(response.media_type).to eq Mime[:turbo_stream]
        expect(response.body).to include("can't be blank")
      end
    end

    describe "DELETE #destroy" do
      it "responds with turbo stream" do
        delete :destroy, params: { id: memo.id, format: :turbo_stream }
        expect(response.media_type).to eq Mime[:turbo_stream]
      end

      context "when unauthorized" do
        before { sign_in other_user }

        it "responds with forbidden turbo stream" do
          delete :destroy, params: { id: memo.id, format: :turbo_stream }
          expect(response).to have_http_status(:forbidden)
          expect(response.media_type).to eq Mime[:turbo_stream]
        end
      end
    end
  end
end
