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
    // フォームターゲットが存在しない場合はスキップ
    if (!this.hasFormTarget) return
    
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
    if (theme === 'high-contrast') {
      document.body.classList.add('high-contrast-theme')
    } else {
      document.body.classList.remove('high-contrast-theme')
    }
  }

  // キーボードショートカットを適用
  applyKeyboardShortcuts(enabled) {
    this.updateKeyboardShortcuts(enabled)
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
    // 成功メッセージは表示しない（静かに完了）
    if (type === 'success') return

    // エラーメッセージのみ表示
    this.showFlashMessage(message)
  }

  // フラッシュメッセージとして表示
  showFlashMessage(message) {
    const flashContainer = document.querySelector('#flash-messages')
    if (!flashContainer) return

    flashContainer.innerHTML = `
      <div class="alert">${message}</div>
    `

    setTimeout(() => {
      flashContainer.innerHTML = ''
    }, 3000)
  }

  // 初期設定を適用
  initializeSettings() {
    const initialTheme = document.body.getAttribute('data-theme')
    if (initialTheme === 'high-contrast') {
      document.body.classList.add('high-contrast-theme')
    }
  }

  // キーボードショートカット設定変更時の連携
  updateKeyboardShortcuts(enabled) {
    // body属性を更新
    document.body.setAttribute('data-shortcuts-enabled', enabled)
    // keyboard-shortcutsコントローラーに通知
    const keyboardShortcutsController = document.querySelector('[data-controller*="keyboard-shortcuts"]')
    if (keyboardShortcutsController) {
      const controller = this.application.getControllerForElementAndIdentifier(keyboardShortcutsController, 'keyboard-shortcuts')
      if (controller && controller.updateShortcutsEnabled) {
        controller.updateShortcutsEnabled()
      }
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
