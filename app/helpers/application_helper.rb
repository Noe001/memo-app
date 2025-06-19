module ApplicationHelper
  # Lucideアイコンを表示するヘルパーメソッド
  def lucide_icon(name, options = {})
    size = options[:size] || 16
    css_class = options[:class] || ""
    aria_hidden = options[:aria_hidden] != false
    
    content_tag :i, "", 
                "data-lucide": name,
                class: "lucide-icon #{css_class}",
                style: "width: #{size}px; height: #{size}px;",
                "aria-hidden": aria_hidden
  end

  # 公開レベルに応じたアイコンを表示
  def visibility_icon(visibility)
    case visibility
    when 'public_memo'
      lucide_icon('globe', title: '公開メモ', class: 'visibility-icon')
    when 'shared'
      lucide_icon('users', title: '共有メモ', class: 'visibility-icon')
    else
      lucide_icon('lock', title: 'プライベートメモ', class: 'visibility-icon')
    end
  end

  # タグアイコン
  def tag_icon
    lucide_icon('tag', size: 14, class: 'tag-icon')
  end

  # 検索アイコン
  def search_icon
    lucide_icon('search', size: 16, class: 'search-icon')
  end

  # 新規作成アイコン
  def plus_icon
    lucide_icon('plus', size: 16, class: 'plus-icon')
  end

  # ユーザーアイコン
  def user_icon
    lucide_icon('user', size: 16, class: 'user-icon')
  end

  # ドキュメントアイコン
  def document_icon
    lucide_icon('file-text', size: 48, class: 'document-icon')
  end
end
