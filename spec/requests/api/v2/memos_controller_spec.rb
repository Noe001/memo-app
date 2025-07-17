require 'rails_helper'

RSpec.describe "Api::V2::Memos", type: :request do
  let(:user) { create(:user) }
  let(:headers) { { 'Authorization' => "Bearer #{user.auth_token}" } }
  let(:memo) { create(:memo, user: user) }

  describe "GET /index" do
    before { create_list(:memo, 3, user: user) }

    it "returns http success" do
      get api_v2_memos_path, headers: headers
      expect(response).to have_http_status(:success)
    end

    context "with pagination" do
      it "returns paginated results" do
        get api_v2_memos_path, params: { page: 1, per_page: 2 }, headers: headers
        expect(JSON.parse(response.body).size).to eq(2)
      end
    end

    context "with sorting" do
      let!(:old_memo) { create(:memo, title: 'AAA', created_at: 1.day.ago, user: user) }
      let!(:new_memo) { create(:memo, title: 'ZZZ', created_at: Time.current, user: user) }

      it "sorts by created_at desc by default" do
        get api_v2_memos_path, headers: headers
        ids = JSON.parse(response.body).map { |m| m['id'] }
        expect(ids.first).to eq(new_memo.id)
      end

      it "sorts by title asc when specified" do
        get api_v2_memos_path, params: { sort: 'title', direction: 'asc' }, headers: headers
        titles = JSON.parse(response.body).map { |m| m['title'] }
        expect(titles.first).to eq('AAA')
      end
    end

    context "when unauthenticated" do
      it "returns unauthorized status" do
        get api_v2_memos_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /search" do
    before do
      create(:memo, title: 'Rails memo', user: user)
      create(:memo, title: 'React memo', user: user)
    end

    it "returns matching memos" do
      get search_api_v2_memos_path, params: { q: 'Rails' }, headers: headers
      expect(JSON.parse(response.body).first['title']).to eq('Rails memo')
    end

    context "with tags" do
      let!(:rails_memo) { create(:memo, title: 'Rails with tags', user: user) }
      let!(:react_memo) { create(:memo, title: 'React with tags', user: user) }
      let!(:long_tag_memo) { create(:memo, title: 'Memo with long tag', user: user) }
      let!(:special_char_memo) { create(:memo, title: 'Memo with special chars', user: user) }

      before do
        rails_memo.tags << create(:tag, name: 'ruby')
        rails_memo.tags << create(:tag, name: 'backend')
        react_memo.tags << create(:tag, name: 'javascript')
        long_tag_memo.tags << create(:tag, name: 'a' * 50) # 境界値テスト用
        special_char_memo.tags << create(:tag, name: 'ruby-on-rails')
      end

      it "returns memos with matching tags" do
        get search_api_v2_memos_path, params: { tags: 'ruby' }, headers: headers
        expect(JSON.parse(response.body).first['title']).to eq('Rails with tags')
      end

      it "returns empty when no matching tags" do
        get search_api_v2_memos_path, params: { tags: 'nonexistent' }, headers: headers
        expect(JSON.parse(response.body)).to be_empty
      end

      it "handles multiple tags" do
        get search_api_v2_memos_path, params: { tags: 'ruby,backend' }, headers: headers
        expect(JSON.parse(response.body).first['title']).to eq('Rails with tags')
      end

      it "handles tags with special characters" do
        get search_api_v2_memos_path, params: { tags: 'ruby-on-rails' }, headers: headers
        expect(JSON.parse(response.body).first['title']).to eq('Memo with special chars')
      end

      it "handles long tag names" do
        get search_api_v2_memos_path, params: { tags: 'a' * 50 }, headers: headers
        expect(JSON.parse(response.body).first['title']).to eq('Memo with long tag')
      end
    end

    context "with combined search" do
      let!(:memo1) { create(:memo, title: 'Rails API', user: user) }
      let!(:memo2) { create(:memo, title: 'React API', user: user) }

      before do
        memo1.tags << create(:tag, name: 'ruby')
        memo2.tags << create(:tag, name: 'javascript')
      end

      it "searches by both keyword and tags" do
        get search_api_v2_memos_path, params: { q: 'API', tags: 'ruby' }, headers: headers
        results = JSON.parse(response.body)
        expect(results.size).to eq(1)
        expect(results.first['title']).to eq('Rails API')
      end
    end
  end

  describe "error handling" do
    it "returns bad request for invalid parameters" do
      get search_api_v2_memos_path, params: { q: '', tags: '' }, headers: headers
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['error']).to include('検索条件を指定してください')
    end

    it "returns error for too long tag name" do
      get search_api_v2_memos_path, params: { tags: 'a' * 51 }, headers: headers
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['error']).to include('タグ名が長すぎます')
    end

    it "returns error for invalid tag format" do
      get search_api_v2_memos_path, params: { tags: 'invalid@tag' }, headers: headers
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['error']).to include('無効なタグ形式です')
    end
  end

  describe "POST /create" do
    let(:valid_attributes) { { title: 'New Memo', content: 'Memo content' } }
    let(:invalid_attributes) { { title: '', content: '' } }

    it "creates a new memo with valid params" do
      expect {
        post api_v2_memos_path, params: { memo: valid_attributes }, headers: headers
      }.to change(Memo, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "returns unprocessable_entity with invalid params" do
      post api_v2_memos_path, params: { memo: invalid_attributes }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors']).to include("タイトルを入力してください")
    end

    context "with tags" do
      it "creates memo with tags" do
        post api_v2_memos_path,
             params: { memo: valid_attributes.merge(tag_names: ['ruby', 'rails']) },
             headers: headers
        expect(JSON.parse(response.body)['tags'].map { |t| t['name'] }).to match_array(['ruby', 'rails'])
      end

      it "handles maximum number of tags" do
        post api_v2_memos_path,
             params: { memo: valid_attributes.merge(tag_names: Array.new(5) { |i| "tag#{i}" }) },
             headers: headers
        expect(response).to have_http_status(:created)
      end

      it "rejects too many tags" do
        post api_v2_memos_path,
             params: { memo: valid_attributes.merge(tag_names: Array.new(6) { |i| "tag#{i}" }) },
             headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include("タグは最大5つまでです")
      end

      it "rejects invalid tag names" do
        post api_v2_memos_path,
             params: { memo: valid_attributes.merge(tag_names: ['invalid@tag']) },
             headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include("タグ名に使用できない文字が含まれています")
      end
    end

    context "with visibility" do
      it "creates public memo by default" do
        post api_v2_memos_path, params: { memo: valid_attributes }, headers: headers
        expect(JSON.parse(response.body)['is_public']).to be true
      end

      it "creates private memo when specified" do
        post api_v2_memos_path,
             params: { memo: valid_attributes.merge(is_public: false) },
             headers: headers
        expect(JSON.parse(response.body)['is_public']).to be false
      end
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get api_v2_memo_path(memo), headers: headers
      expect(response).to have_http_status(:success)
    end

    context "when memo not found" do
      it "returns not_found status" do
        get api_v2_memo_path(id: 'invalid'), headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /update" do
    let(:new_attributes) { { title: 'Updated title', content: 'Updated content' } }

    it "updates the requested memo" do
      patch api_v2_memo_path(memo), params: { memo: new_attributes }, headers: headers
      memo.reload
      expect(memo.title).to eq('Updated title')
      expect(response).to have_http_status(:ok)
    end

    it "returns unprocessable_entity with invalid params" do
      patch api_v2_memo_path(memo), params: { memo: { title: '' } }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors']).to include("タイトルを入力してください")
    end

    context "with tags" do
      it "updates memo tags" do
        patch api_v2_memo_path(memo),
              params: { memo: { tag_names: ['new_tag'] } },
              headers: headers
        expect(memo.reload.tags.pluck(:name)).to include('new_tag')
      end

      it "clears tags when empty array provided" do
        memo.tags << create(:tag, name: 'old_tag')
        patch api_v2_memo_path(memo),
              params: { memo: { tag_names: [] } },
              headers: headers
        expect(memo.reload.tags).to be_empty
      end
    end

    context "with visibility" do
      it "updates memo visibility" do
        patch api_v2_memo_path(memo),
              params: { memo: { is_public: false } },
              headers: headers
        expect(memo.reload.is_public).to be false
      end
    end

    context "with content length limits" do
      it "rejects too long content" do
        patch api_v2_memo_path(memo),
              params: { memo: { content: 'a' * 10001 } },
              headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include("コンテンツは10000文字以内で入力してください")
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested memo" do
      memo # create memo
      expect {
        delete api_v2_memo_path(memo), headers: headers
      }.to change(Memo, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "error handling" do
    context "with invalid auth token" do
      it "returns unauthorized status" do
        get api_v2_memos_path, headers: { 'Authorization' => 'Bearer invalid' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with expired auth token" do
      it "returns unauthorized status" do
        expired_token = JWT.encode({ exp: 1.day.ago.to_i }, Rails.application.credentials.secret_key_base)
        get api_v2_memos_path, headers: { 'Authorization' => "Bearer #{expired_token}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
