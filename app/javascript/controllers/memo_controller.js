import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sortSelect", "searchForm", "memoItem"]

  connect() {
    this.boundAutoSubmit = this.autoSubmit.bind(this)
  }

  disconnect() {
    // Clean up any event listeners if needed
  }

  // 並べ替えの自動送信
  autoSubmit(event) {
    const form = event.target.closest('form')
    if (form) {
      // 少し遅延させてユーザーが選択を完了できるようにする
      setTimeout(() => {
        form.submit()
      }, 100)
    }
  }

  // 検索フォームの送信
  search(event) {
    event.preventDefault()
    const form = event.target
    const formData = new FormData(form)
    const searchWord = formData.get('word')
    
    if (searchWord && searchWord.trim()) {
      form.submit()
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
} 
 