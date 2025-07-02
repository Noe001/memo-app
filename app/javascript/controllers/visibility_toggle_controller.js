import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "select", "icon"]

  connect() {
    // selectターゲットが存在する場合のみアイコンを更新
    if (this.hasSelectTarget) {
      this.updateIcon()
    }
  }

  // トグルボタンをクリックした時の処理
  toggle() {
    const selectElement = this.selectTarget
    const currentValue = selectElement.value
    
    // 次の値を決定
    let nextValue
    switch (currentValue) {
      case 'private_memo':
        nextValue = 'public_memo'
        break
      case 'public_memo':
        nextValue = 'shared'
        break
      case 'shared':
        nextValue = 'private_memo'
        break
      default:
        nextValue = 'private_memo'
    }
    
    // 値を更新
    selectElement.value = nextValue
    
    // アイコンを更新
    this.updateIcon()
    
    // フォームを送信（編集の場合のみ）
    if (this.formTarget.tagName === 'FORM') {
      this.update()
    }
  }

  // セレクトボックスが変更された時の処理（編集時）
  update() {
    if (this.formTarget.tagName === 'FORM') {
      // 編集中のメモの場合、自動保存
      const formData = new FormData(this.formTarget)
      
      fetch(this.formTarget.action, {
        method: this.formTarget.method.toUpperCase(),
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
      })
      .then(response => response.json())
      .then(data => {
        if (data.status === 'success') {
          this.showSaveStatus('公開設定を更新しました', 'success')
        } else {
          this.showSaveStatus('更新に失敗しました', 'error')
        }
      })
      .catch(error => {
        console.error('Error:', error)
        this.showSaveStatus('更新に失敗しました', 'error')
      })
    }
    
    this.updateIcon()
  }

  // アイコンを更新
  updateIcon() {
    if (!this.hasSelectTarget) return
    
    const selectElement = this.selectTarget
    const iconElement = this.element.querySelector('.visibility-icon')
    
    if (!iconElement) return
    
    const currentValue = selectElement.value
    let iconName
    
    switch (currentValue) {
      case 'private_memo':
        iconName = 'lock'
        break
      case 'public_memo':
        iconName = 'globe'
        break
      case 'shared':
        iconName = 'users'
        break
      default:
        iconName = 'lock'
    }
    
    // Lucideアイコンを更新
    iconElement.setAttribute('data-lucide', iconName)
    
    // Lucideアイコンを再レンダリング
    if (typeof lucide !== 'undefined') {
      lucide.createIcons()
    }
  }

  // 保存状況を表示
  showSaveStatus(message, type) {
    // 既存の状況表示を削除
    const existingStatus = document.querySelector('.save-status')
    if (existingStatus) {
      existingStatus.remove()
    }
    
    // 新しい状況表示を作成
    const statusElement = document.createElement('div')
    statusElement.className = `save-status save-status-${type}`
    statusElement.textContent = message
    
    // ヘッダーに追加
    const headerElement = document.querySelector('.memo-main-header')
    if (headerElement) {
      headerElement.appendChild(statusElement)
      
      // 3秒後に削除
      setTimeout(() => {
        if (statusElement && statusElement.parentNode) {
          statusElement.remove()
        }
      }, 3000)
    }
  }
} 
 