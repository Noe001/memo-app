import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]
  static values = { enabled: Boolean }

  connect() {
    this.bindKeyboardShortcuts()
    this.updateShortcutsEnabled()
  }

  // キーボードショートカットの有効/無効を更新
  updateShortcutsEnabled() {
    const enabled = document.body.getAttribute('data-shortcuts-enabled') === 'true'
    this.enabledValue = enabled
  }

  // キーボードショートカットを設定
  bindKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      this.handleGlobalKeyboardShortcuts(e)
    })
  }

  // グローバルキーボードショートカットを処理
  handleGlobalKeyboardShortcuts(e) {
    // 設定から有効/無効を確認
    const enabled = document.body.getAttribute('data-shortcuts-enabled') === 'true'
    if (!enabled) return

    // 入力フィールドでのショートカットを一部制限
    const isInputField = e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.contentEditable === 'true'

    // Ctrl/Cmd + N: 新しいメモ
    if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
      e.preventDefault()
      const createBtn = document.querySelector('.create-memo-btn, .create-new-btn, #create_new')
      if (createBtn) createBtn.click()
    }

    // Ctrl/Cmd + S: 手動保存（リアルタイム保存をトリガー）
    if ((e.ctrlKey || e.metaKey) && e.key === 's') {
      e.preventDefault()
      // フォーカスしているフィールドがあれば、そのフィールドのauto-saveをトリガー
      const activeElement = document.activeElement
      if (activeElement && (activeElement.tagName === 'INPUT' || activeElement.tagName === 'TEXTAREA')) {
        const autoSaveController = activeElement.closest('[data-controller*="auto-save"]')
        if (autoSaveController) {
          // blur イベントをトリガーして保存を実行
          activeElement.blur()
          activeElement.focus()
        }
      }
    }

    // Ctrl/Cmd + F: 検索（入力フィールド以外）
    if ((e.ctrlKey || e.metaKey) && e.key === 'f' && !isInputField) {
      e.preventDefault()
      const searchInput = document.querySelector('.search-input, .search_box')
      if (searchInput) searchInput.focus()
    }

    // Ctrl/Cmd + /: ショートカット一覧表示
    if ((e.ctrlKey || e.metaKey) && e.key === '/') {
      e.preventDefault()
      this.toggleShortcutsPanel()
    }

    // Escape: 編集終了・パネル閉じる
    if (e.key === 'Escape') {
      if (this.hasPanelTarget && this.panelTarget.style.display === 'block') {
        this.hideShortcutsPanel()
      } else {
        document.activeElement.blur()
      }
    }

    // 矢印キー: メモ一覧の選択移動（入力フィールド以外）
    if (!isInputField && (e.key === 'ArrowUp' || e.key === 'ArrowDown')) {
      this.handleMemoNavigation(e)
    }
  }

  // メモ一覧の選択移動
  handleMemoNavigation(e) {
    const memoItems = document.querySelectorAll('.memo-item')
    const activeMemo = document.querySelector('.memo-item.active')
    
    if (!memoItems.length) return

    e.preventDefault()
    
    let currentIndex = -1
    if (activeMemo) {
      currentIndex = Array.from(memoItems).indexOf(activeMemo)
    }

    let nextIndex = currentIndex
    
    if (e.key === 'ArrowUp') {
      nextIndex = currentIndex > 0 ? currentIndex - 1 : memoItems.length - 1
    } else if (e.key === 'ArrowDown') {
      nextIndex = currentIndex < memoItems.length - 1 ? currentIndex + 1 : 0
    }

    if (nextIndex >= 0 && nextIndex < memoItems.length) {
      memoItems[nextIndex].click()
    }
  }

  // ショートカットパネルの表示/非表示を切り替え
  toggleShortcutsPanel() {
    if (this.hasPanelTarget) {
      const isVisible = this.panelTarget.style.display === 'block'
      if (isVisible) {
        this.hideShortcutsPanel()
      } else {
        this.showShortcutsPanel()
      }
    }
  }

  // ショートカットパネルを表示
  showShortcutsPanel() {
    if (this.hasPanelTarget) {
      this.panelTarget.style.display = 'block'
      this.panelTarget.style.opacity = '1'
      this.panelTarget.style.transform = 'translateY(0)'
    }
  }

  // ショートカットパネルを非表示
  hideShortcutsPanel() {
    if (this.hasPanelTarget) {
      this.panelTarget.style.opacity = '0'
      this.panelTarget.style.transform = 'translateY(-10px)'
      setTimeout(() => {
        if (this.hasPanelTarget) {
          this.panelTarget.style.display = 'none'
        }
      }, 200)
    }
  }

  // 外部からの設定更新
  enabledValueChanged() {
    // 設定が変更された時の処理
    const enabled = this.enabledValue
    document.body.setAttribute('data-shortcuts-enabled', enabled)
  }
} 
 