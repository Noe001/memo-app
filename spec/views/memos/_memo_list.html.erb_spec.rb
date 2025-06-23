require 'rails_helper'

RSpec.describe "memos/_memo_list.html.erb", type: :view do
  let(:user) { create(:user) }
  let(:tag1) { create(:tag, name: "テスト", color: "#FF5733") }
  let(:tag2) { create(:tag, name: "重要", color: "#33C3FF") }

  before do
    # ヘルパーメソッドをスタブ化
    allow(view).to receive(:document_icon).and_return('<i class="document-icon"></i>'.html_safe)
    allow(view).to receive(:visibility_icon).and_return('<i class="visibility-icon"></i>'.html_safe)
    allow(view).to receive(:paginate).and_return(''.html_safe)
    allow(view).to receive(:respond_to?).with(:paginate).and_return(false)
  end

  context "when memos exist" do
    let(:memo1) do 
      create(:memo, 
        user: user, 
        title: "テストメモ1", 
        description: "これはテスト用のメモです。長い説明文を含んでいます。",
        updated_at: 1.day.ago
      )
    end
    
    let(:memo2) do 
      create(:memo, 
        user: user, 
        title: "テストメモ2", 
        description: "短い説明",
        updated_at: 2.days.ago
      )
    end

    before do
      # タグの関連付け
      memo1.tags << tag1
      memo1.tags << tag2
      memo2.tags << tag1
      
      assign(:memos, [memo1, memo2])
      assign(:memo_id, memo1.id)
      
      render
    end

    it "displays memo list container" do
      expect(rendered).to have_selector('.memo-list[role="list"]')
    end

    it "displays memo items" do
      expect(rendered).to have_selector('.memo-item', count: 2)
      expect(rendered).to have_selector('.memo-item.active', count: 1) # Active memo
    end

    it "displays memo titles and dates" do
      expect(rendered).to have_selector('.memo-title', text: 'テストメモ1')
      expect(rendered).to have_selector('.memo-title', text: 'テストメモ2')
      expect(rendered).to have_selector('.memo-date')
    end

    it "displays memo previews" do
      expect(rendered).to have_selector('.memo-preview')
      expect(rendered).to include('これはテスト用のメモです')
    end

    it "displays memo tags" do
      expect(rendered).to have_selector('.memo-tags')
      expect(rendered).to have_selector('.memo-tag', text: 'テスト')
      expect(rendered).to have_selector('.memo-tag', text: '重要')
    end

    it "displays tag colors" do
      expect(rendered).to include('background-color: #FF573315')
      expect(rendered).to include('color: #FF5733')
    end

    it "displays visibility indicators" do
      expect(rendered).to have_selector('.memo-visibility')
    end

    it "has proper links and data attributes" do
      expect(rendered).to have_link(href: memo_path(memo1))
      expect(rendered).to have_selector('[data-memo-id]')
      expect(rendered).to have_selector('[data-action="click->memo#selectMemo"]')
    end
  end

  context "when no memos exist" do
    before do
      assign(:memos, [])
      assign(:memo_id, nil)
      
      render
    end

    it "displays empty state" do
      expect(rendered).to have_selector('.empty-state[role="status"]')
      expect(rendered).to have_selector('.empty-icon')
      expect(rendered).to have_selector('h3', text: 'メモがありません')
      expect(rendered).to have_selector('p', text: '新しいメモを作成してみましょう')
    end

    it "displays create memo button" do
      expect(rendered).to have_link('最初のメモを作成', href: memos_path)
      expect(rendered).to have_selector('.btn.btn-primary')
    end
  end

  context "when memo has many tags" do
    let(:memo_with_many_tags) do
      memo = create(:memo, user: user, title: "多数タグメモ")
      5.times do |i|
        tag = create(:tag, name: "タグ#{i+1}")
        memo.tags << tag
      end
      memo
    end

    before do
      assign(:memos, [memo_with_many_tags])
      assign(:memo_id, nil)
      
      render
    end

    it "displays tag limit indicator" do
      expect(rendered).to have_selector('.memo-tag-more', text: '+2')
    end
  end
end 
