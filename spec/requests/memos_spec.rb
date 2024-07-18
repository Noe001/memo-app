require 'rails_helper'

RSpec.describe "Memos", type: :request do
  describe "GET #index" do
    let(:user) { create(:user) }
    let!(:memo) { create(:memo, user: user) }

    before do
      sign_in user
    end

    it "assigns @memos" do
      get :index
      expect(assigns(:memos)).to eq([memo])
    end
  end

  describe "GET #show" do
    let(:user) { create(:user) }
    let!(:memo) { create(:memo, user: user) }

    before do
      sign_in user
    end

    it "assigns the requested memo as @selected" do
      get :show, params: { id: memo.to_param }
      expect(assigns(:selected)).to eq(memo)
    end
  end

  describe "POST #create" do
    let(:user) { create(:user) }

    before do
      sign_in user
    end

    context "with valid params" do
      it "creates a new Memo" do
        expect {
          post :create, params: { memo: attributes_for(:memo) }
        }.to change(Memo, :count).by(1)
      end
    end
  end

  describe "PUT #update" do
    let(:user) { create(:user) }
    let!(:memo) { create(:memo, user: user) }

    before do
      sign_in user
    end

    context "with valid params" do
      it "updates the requested memo" do
        new_attributes = attributes_for(:memo, title: "Updated Title")
        put :update, params: { id: memo.to_param, memo: new_attributes }
        memo.reload
        expect(memo.title).to eq("Updated Title")
      end
    end
  end

  describe "DELETE #destroy" do
    let(:user) { create(:user) }
    let!(:memo) { create(:memo, user: user) }

    before do
      sign_in user
    end

    it "destroys the requested memo" do
      expect {
        delete :destroy, params: { id: memo.to_param }
      }.to change(Memo, :count).by(-1)
    end
  end

  describe "GET #search" do
    let(:user) { create(:user) }
    let!(:memo) { create(:memo, user: user, title: "Test Memo") }

    before do
      sign_in user
    end

    it "assigns @memos with matching records" do
      get :search, params: { word: "Test" }
      expect(assigns(:memos)).to eq([memo])
    end
  end
end
