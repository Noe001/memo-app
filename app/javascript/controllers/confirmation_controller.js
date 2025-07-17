import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "confirmButton", "cancelButton"]
  static values = {
    deleteUrl: String
  }

  connect() {
    // イベントリスナー設定
    this.confirmButtonTarget.addEventListener('click', this.handleConfirm.bind(this))
    this.cancelButtonTarget.addEventListener('click', this.hide.bind(this))
  }

  disconnect() {
    // イベントリスナー削除
    this.confirmButtonTarget.removeEventListener('click', this.handleConfirm)
    this.cancelButtonTarget.removeEventListener('click', this.hide)
  }

  show(event) {
    event.preventDefault()
    event.stopPropagation()
    
    // 削除URLを設定
    const deleteUrl = event.currentTarget.dataset.deleteUrl
    if (deleteUrl) {
      this.deleteUrlValue = deleteUrl
    }
    
    // モーダル表示
    this.dialogTarget.classList.remove('hidden')
    this.dialogTarget.classList.add('flex')
  }

  hide() {
    this.dialogTarget.classList.add('hidden')
    this.dialogTarget.classList.remove('flex')
  }

  handleConfirm() {
    if (!this.deleteUrlValue) return
    
    fetch(this.deleteUrlValue, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'application/json'
      },
      credentials: 'same-origin'
    })
      .then(response => {
        if (!response.ok) throw new Error('Delete failed')
        return response.json()
      })
      .then(data => {
        if (data.redirect) {
          window.location.href = data.redirect
        } else if (data.reload) {
          window.location.reload()
        }
      })
      .catch(error => {
        console.error('Delete error:', error)
        this.hide()
      })
  }
}
