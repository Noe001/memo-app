import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["popup", "overlay", "form", "saveStatus"]
  static classes = ["active"]
  static values = { 
    url: String,
    shortcutsEnabled: Boolean 
  }

  initialize() {
    this.scrollPosition = 0
    this.initializeSettings()
  }

  connect() {
    this.bindSettingOptions()
    this.bindKeyboardShortcuts()
  }

  // 設定ポップアップを開く
  open() {
    this.overlayTarget.classList.add(this.activeClass)
    this.popupTarget.classList.add(this.activeClass)
    this.disableScroll()
  }

  // 設定ポップアップを閉じる
  close() {
    this.overlayTarget.classList.remove(this.activeClass)
    this.popupTarget.classList.remove(this.activeClass)
    this.enableScroll()
  }

  // オーバーレイクリックで閉じる
  closeOnOverlay(event) {
    if (event.target === this.overlayTarget) {
      this.close()
    }
  }

  // 設定変更イベントを処理
  bindSettingOptions() {
    const settingOptions = this.formTarget.querySelectorAll('input[data-setting-option]')
    
    settingOptions.forEach(option => {
      option.addEventListener('change', (e) => {
        this.handleSettingChange(e.target)
      })
    })
  }

  // 設定変更を処理
  handleSettingChange(input) {
    const settingType = input.dataset.settingOption
    let value

    if (input.type === 'checkbox') {
      value = input.checked
    } else if (input.checked) {
      value = input.value
    } else {
      return
    }

    // 即座に設定を適用
    switch (settingType) {
      case 'theme':
        if (input.checked) this.applyTheme(value)
        break
      case 'font_size':
        if (input.checked) this.applyFontSize(value)
        break
      case 'keyboard_shortcuts':
        this.applyKeyboardShortcuts(value)
        break
    }

    // サーバーに保存
    this.saveSettings()
  }

  // テーマを適用
  applyTheme(theme) {
    document.body.setAttribute('data-theme', theme)
    // Remove any legacy theme classes (no longer needed)
    document.body.classList.remove('high-contrast-theme')
  }

  // フォントサイズを適用
  applyFontSize(size) {
    document.body.classList.remove('font-small', 'font-medium', 'font-large', 'font-x-large')
    if (size && size !== 'medium') {
      document.body.classList.add('font-' + size.replace('-', '-'))
    }
  }

  // キーボードショートカットを適用
  applyKeyboardShortcuts(enabled) {
    document.body.setAttribute('data-shortcuts-enabled', enabled)
    this.shortcutsEnabledValue = enabled
  }

  // 設定をサーバーに保存
  saveSettings() {
    if (!this.formTarget) return

    const formData = new FormData(this.formTarget)
    
    fetch(this.urlValue, {
      method: 'PATCH',
      body: formData,
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.status === 'success') {
        this.showSaveStatus(data.message, 'success')
      } else {
        this.showSaveStatus(data.message || '保存に失敗しました', 'error')
      }
    })
    .catch(error => {
      console.error('Error:', error)
      this.showSaveStatus('保存に失敗しました', 'error')
    })
  }

  // 保存状態を表示
  showSaveStatus(message, type = 'success') {
    this.saveStatusTarget.innerHTML = `
      <div class="popup-save-message popup-save-message-${type}">
        <i data-lucide="${type === 'success' ? 'check' : 'x'}" class="save-icon"></i>
        <span>${message}</span>
      </div>
    `
    
    if (typeof lucide !== 'undefined') {
      lucide.createIcons()
    }
    
    setTimeout(() => {
      this.saveStatusTarget.innerHTML = ''
    }, 3000)
  }

  // 初期設定を適用
  initializeSettings() {
    const initialTheme = document.body.getAttribute('data-theme')
    // Remove any legacy theme classes (no longer needed)
    document.body.classList.remove('high-contrast-theme')
  }

  // キーボードショートカットを設定
  bindKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      this.handleGlobalKeyboardShortcuts(e)
    })
  }

  // グローバルキーボードショートカットを処理
  handleGlobalKeyboardShortcuts(e) {
    if (!this.shortcutsEnabledValue) return
    
    // Ctrl/Cmd + N: 新しいメモ
    if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
      e.preventDefault()
      const createBtn = document.querySelector('.create-memo-btn')
      if (createBtn) createBtn.click()
    }
    
    // Ctrl/Cmd + S: 保存
    if ((e.ctrlKey || e.metaKey) && e.key === 's') {
      e.preventDefault()
      const saveBtn = document.querySelector('.save-btn, .form-actions .btn-primary')
      if (saveBtn) saveBtn.click()
    }
    
    // Ctrl/Cmd + F: 検索
    if ((e.ctrlKey || e.metaKey) && e.key === 'f') {
      e.preventDefault()
      const searchInput = document.querySelector('.search-input')
      if (searchInput) searchInput.focus()
    }
  }

  // スクロール制御メソッド
  disableScroll() {
    this.scrollPosition = window.pageYOffset || document.documentElement.scrollTop
    document.body.style.position = 'fixed'
    document.body.style.top = `-${this.scrollPosition}px`
    document.body.style.width = '100%'
    document.body.style.overflowY = 'scroll'
  }

  enableScroll() {
    document.body.style.position = ''
    document.body.style.top = ''
    document.body.style.width = ''
    document.body.style.overflowY = ''
    window.scrollTo(0, this.scrollPosition)
  }
} 
