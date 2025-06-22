require 'rails_helper'

RSpec.describe "errors/not_found.html.erb", type: :view do
  before do
    render
  end

  it "displays error page title" do
    expect(rendered).to have_selector('title', text: 'ページが見つかりません - Memo App')
  end

  it "displays error icon" do
    expect(rendered).to have_selector('.error-icon', text: '🔍')
  end

  it "displays error title" do
    expect(rendered).to have_selector('h1.error-title', text: 'ページが見つかりません')
  end

  it "displays error message" do
    expect(rendered).to have_selector('.error-message')
    expect(rendered).to include('お探しのページは存在しないか、移動された可能性があります')
  end

  it "displays navigation buttons" do
    expect(rendered).to have_link('ホームに戻る', href: root_path)
    expect(rendered).to have_link('ログインページ', href: new_sessions_path)
  end

  it "displays suggestions section" do
    expect(rendered).to have_selector('.suggestions h3', text: 'こちらもお試しください')
    expect(rendered).to have_link('メモ一覧を見る')
    expect(rendered).to have_link('新しいメモを作成')
    expect(rendered).to have_link('アカウントを作成')
  end

  it "has proper structure and classes" do
    expect(rendered).to have_selector('.error-container')
    expect(rendered).to have_selector('.error-actions')
    expect(rendered).to have_selector('.btn.btn-primary')
    expect(rendered).to have_selector('.btn.btn-secondary')
  end
end
