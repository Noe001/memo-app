require 'rails_helper'

RSpec.describe "memos/_sidebar.html.erb", type: :view do
  let(:user) { create(:user) }
  let(:memo1) { create(:memo, user: user, title: "Test Memo 1", created_at: 1.day.ago) }
  let(:memo2) { create(:memo, user: user, title: "Test Memo 2", created_at: 2.days.ago) }
  let(:tag1) { create(:tag, name: "テスト") }
  let(:tag2) { create(:tag, name: "重要") }

  before do
    assign(:memos, [memo1, memo2])
    assign(:tags, { "テスト" => 2, "重要" => 1 })
    assign(:memo_id, memo1.id)
    
    # ヘルパーメソッドをスタブ化
    allow(view).to receive(:plus_icon).and_return('<i class="plus-icon"></i>'.html_safe)
    allow(view).to receive(:search_icon).and_return('<i class="search-icon"></i>'.html_safe)
    
    render
  end

  it "displays the sidebar navigation" do
    expect(rendered).to have_selector('.sidebar[role="navigation"]')
    expect(rendered).to have_selector('.sidebar[aria-label="Memo navigation"]')
  end

  it "displays the create new button" do
    expect(rendered).to have_link('新規作成', href: memos_path)
    expect(rendered).to have_selector('#create_new')
  end

  it "displays the search form" do
    expect(rendered).to have_selector('.search-form')
    expect(rendered).to have_field('word', placeholder: 'メモを検索...')
    expect(rendered).to have_button('検索実行')
  end

  it "displays tag filter when tags are present" do
    expect(rendered).to have_selector('.tag-filter')
    expect(rendered).to have_selector('.filter-title', text: 'タグ')
    expect(rendered).to have_selector('.tag-item[data-tag="テスト"]')
    expect(rendered).to have_selector('.tag-item[data-tag="重要"]')
    expect(rendered).to have_selector('.tag-count', text: '2')
    expect(rendered).to have_selector('.tag-count', text: '1')
  end

  it "renders the memo list partial" do
    expect(rendered).to render_template('memo_list')
  end

  context "when no tags are present" do
    before do
      assign(:tags, {})
      render
    end

    it "does not display tag filter" do
      expect(rendered).not_to have_selector('.tag-filter')
    end
  end
end 
