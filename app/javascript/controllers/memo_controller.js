import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "sortSelect",
    "searchInput",
    "tagItem",
    "memoItem"
  ]

  static values = {
    searchUrl: String
  }

  connect() {
    // デバウンス設定（500msに延長）
    this.debouncedSearch = this.debounce(() => this.performSearch(), 500)

    // 選択タグを保持するセット
    this.selectedTags = new Set()

    // 初期状態で active クラスが付いたタグをセットに追加
    if (this.hasTagItemTargets) {
      this.tagItemTargets.forEach(tagBtn => {
        if (tagBtn.classList.contains('active')) {
          this.selectedTags.add(tagBtn.dataset.tag)
        }
      })
    }

    if (this.hasSearchInputTarget) {
      this.searchInputTarget.addEventListener('input', this.debouncedSearch)
    }
  }

  disconnect() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.removeEventListener('input', this.debouncedSearch)
    }
  }

  // タグボタンのトグル
  toggleTag(event) {
    event.preventDefault()
    event.stopPropagation()
    const btn = event.currentTarget
    btn.classList.toggle('active')
    const tagValue = btn.dataset.tag

    if (btn.classList.contains('active')) {
      this.selectedTags.add(tagValue)
    } else {
      this.selectedTags.delete(tagValue)
    }

    this.performSearch()
  }

  // 並べ替えの自動送信（従来機能）
  autoSubmit(event) {
    const form = event.target.closest('form')
    if (form) {
      setTimeout(() => {
        form.submit()
      }, 100)
    }
  }

  // パラメータを組み立てて検索を実行
  performSearch(clickedTag = null) {
    if (!this.hasSearchUrlValue) return

    const params = new URLSearchParams()

    // キーワード
    if (this.hasSearchInputTarget) {
      const word = this.searchInputTarget.value.trim()
      if (word) params.set('word', word)
    }

    // タグ (AND 条件)
    this.selectedTags.forEach(tag => params.append('tags[]', tag))

    // Fetch Turbo Stream
    fetch(`${this.searchUrlValue}?${params.toString()}`, {
      headers: {
        'Accept': 'text/vnd.turbo-stream.html'
      },
      credentials: 'same-origin'
    })
      .then(response => {
        if (!response.ok) throw new Error('Network response was not ok')
        return response.text()
      })
      .then(html => {
        const wrapper = document.createElement('div')
        wrapper.innerHTML = html
        wrapper.querySelectorAll('turbo-stream').forEach(stream => {
          if (window.Turbo) {
            window.Turbo.renderStreamMessage(stream.outerHTML)
          }
        })
      })
      .catch(error => console.error('Live search error:', error))
  }

  // ユーティリティ: デバウンス
  debounce(callback, delay) {
    let timer
    return (...args) => {
      clearTimeout(timer)
      timer = setTimeout(() => {
        callback.apply(this, args)
      }, delay)
    }
  }

  // 並べ替えフォームの送信
  sort(event) {
    const form = event.target.closest('form')
    if (form) {
      form.submit()
    }
  }

  // メモアイテムを選択
  selectMemo(event) {
    const clickedItem = event.currentTarget
    const memoId = clickedItem.dataset.memoId
    
    // 既存のアクティブアイテムからactiveクラスを削除
    const activeItems = this.element.querySelectorAll('.memo-item.active')
    activeItems.forEach(item => item.classList.remove('active'))
    
    // クリックされたアイテムにactiveクラスを追加
    clickedItem.classList.add('active')
    
    // 選択されたメモのIDを記録（キーボードナビゲーション用）
    this.selectedMemoId = memoId
    
    // デフォルトのリンク動作は継続させる（preventDefault しない）
    // これによりpage遷移も正常に動作する
  }

  // キーボードナビゲーション（オプション）
  handleKeydown(event) {
    // 矢印キーでのメモ選択（将来の機能拡張用）
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault()
      this.navigateMemos(event.key === 'ArrowDown' ? 1 : -1)
    }
  }

  navigateMemos(direction) {
    const memoItems = Array.from(this.element.querySelectorAll('.memo-item'))
    const currentIndex = memoItems.findIndex(item => item.classList.contains('active'))
    
    if (memoItems.length === 0) return
    
    let newIndex
    if (currentIndex === -1) {
      newIndex = direction > 0 ? 0 : memoItems.length - 1
    } else {
      newIndex = currentIndex + direction
      if (newIndex < 0) newIndex = memoItems.length - 1
      if (newIndex >= memoItems.length) newIndex = 0
    }
    
    // 新しいアイテムを選択
    memoItems.forEach(item => item.classList.remove('active'))
    memoItems[newIndex].classList.add('active')
    memoItems[newIndex].scrollIntoView({ behavior: 'smooth', block: 'nearest' })
  }

  // auto-save用: Ajax失敗時のエラー表示
  handleAutoSaveError(error) {
    alert('保存に失敗しました: ' + (error.message || 'ネットワークエラー'));
  }
} 
 