import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  static targets = ["status"]

  connect() {
    this.saveTimeout = null
    this.isNewRecord = this.element.action.includes('/memos') && !this.element.action.match(/\/memos\/\d+/)
    this.memoId = null
    this.hasContent = false
    
    // 新規作成時の初期チェック
    if (this.isNewRecord) {
      this.checkInitialContent()
    }
  }

  disconnect() {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
    }
  }

  // フィールドが変更された時の処理
  saveField(event) {
    // デバウンス処理（入力中は頻繁に保存しない）
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
    }

    this.saveTimeout = setTimeout(() => {
      this.performSave(event.target)
    }, 1000) // 1秒後に保存
  }

  // 初期コンテンツの確認（新規作成時）
  checkInitialContent() {
    const titleField = this.element.querySelector('[name$="[title]"]')
    const descriptionField = this.element.querySelector('[name$="[description]"]')
    const tagsField = this.element.querySelector('[name="tags"]')
    
    const hasTitle = titleField && titleField.value.trim()
    const hasDescription = descriptionField && descriptionField.value.trim()
    const hasTags = tagsField && tagsField.value.trim()
    
    this.hasContent = hasTitle || hasDescription || hasTags
  }

  // 実際の保存処理
  async performSave(changedField) {
    const formData = new FormData(this.element)
    
    // 新規作成の場合、内容がある場合のみ作成
    if (this.isNewRecord) {
      const title = formData.get('memo[title]') || formData.get('memo_to_add[title]')
      const description = formData.get('memo[description]') || formData.get('memo_to_add[description]')
      const tags = formData.get('tags')
      
      const hasContent = (title && title.trim()) || 
                        (description && description.trim()) || 
                        (tags && tags.trim())
      
      if (!hasContent) {
        return // 内容がない場合は保存しない
      }
      
      // 初回保存時は新規作成
      if (!this.memoId) {
        await this.createNewMemo(formData)
        return
      }
    }

    // 既存メモの更新または作成済みメモの更新
    this.updateMemo(formData)
  }

  // 新規メモの作成
  async createNewMemo(formData) {
    this.showSaveStatus('保存中...', 'saving')
    
    try {
      const response = await fetch(this.urlValue, {
        method: 'POST',
        body: formData,
        headers: {
          'Accept': 'text/vnd.turbo-stream.html, application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
      })

      if (response.ok) {
        const contentType = response.headers.get('content-type')
        
        if (contentType && contentType.includes('turbo-stream')) {
          // Turbo Streamレスポンスの場合、HTMLを取得して処理
          const html = await response.text()
          const tempDiv = document.createElement('div')
          tempDiv.innerHTML = html
          
          // Turbo Streamアクションを実行
          const turboStreamElements = tempDiv.querySelectorAll('turbo-stream')
          turboStreamElements.forEach(element => {
            // Turboはグローバルに利用可能
            if (window.Turbo) {
              window.Turbo.renderStreamMessage(element.outerHTML)
            }
          })
          
          // 作成されたメモのIDを取得（フォームからまたは最新のメモから）
          const createdMemoElement = document.querySelector('#memo-list .memo-item:first-child')
          if (createdMemoElement) {
            const memoId = createdMemoElement.dataset.memoId
            if (memoId) {
              this.memoId = memoId
              this.isNewRecord = false
              
              // URLを更新用に変更
              this.urlValue = `/memos/${this.memoId}`
              this.element.action = this.urlValue
              
              // URLを更新（ブラウザの履歴に追加せずに）
              if (window.history && window.history.replaceState) {
                window.history.replaceState({}, '', `/memos/${this.memoId}`)
              }
            }
          }
          
          this.showSaveStatus('保存完了', 'success')
        } else {
          // JSONレスポンスの場合（フォールバック）
          const data = await response.json()
          if (data.memo_id) {
            this.memoId = data.memo_id
            this.isNewRecord = false
            
            // URLを更新用に変更
            this.urlValue = `/memos/${this.memoId}`
            this.element.action = this.urlValue
            
            this.showSaveStatus('保存完了', 'success')
            
            // URLを更新（ブラウザの履歴に追加せずに）
            if (window.history && window.history.replaceState) {
              window.history.replaceState({}, '', `/memos/${this.memoId}`)
            }
          }
        }
      } else {
        this.showSaveStatus('保存に失敗しました', 'error')
      }
    } catch (error) {
      console.error('Save error:', error)
      this.showSaveStatus('保存に失敗しました', 'error')
    }
  }

  // 既存メモの更新
  async updateMemo(formData) {
    this.showSaveStatus('保存中...', 'saving')
    
    try {
      const response = await fetch(this.urlValue, {
        method: 'PATCH',
        body: formData,
        headers: {
          'Accept': 'text/vnd.turbo-stream.html, application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
      })

      if (response.ok) {
        const contentType = response.headers.get('content-type')
        
        if (contentType && contentType.includes('turbo-stream')) {
          // Turbo Streamレスポンスの場合、HTMLを取得して処理
          const html = await response.text()
          const tempDiv = document.createElement('div')
          tempDiv.innerHTML = html
          
          // Turbo Streamアクションを実行
          const turboStreamElements = tempDiv.querySelectorAll('turbo-stream')
          turboStreamElements.forEach(element => {
            // Turboはグローバルに利用可能
            if (window.Turbo) {
              window.Turbo.renderStreamMessage(element.outerHTML)
            }
          })
          
          this.showSaveStatus('保存完了', 'success')
        } else {
          // JSONレスポンスの場合（フォールバック）
          const data = await response.json()
          this.showSaveStatus('保存完了', 'success')
        }
      } else {
        this.showSaveStatus('保存に失敗しました', 'error')
      }
    } catch (error) {
      console.error('Update error:', error)
      this.showSaveStatus('保存に失敗しました', 'error')
    }
  }

  // 保存状況の表示
  showSaveStatus(message, type) {
    // 既存のステータス表示を削除
    const existingStatus = document.querySelector('.auto-save-status')
    if (existingStatus) {
      existingStatus.remove()
    }

    // 新しいステータス表示を作成
    const statusElement = document.createElement('div')
    statusElement.className = `auto-save-status auto-save-status-${type}`
    statusElement.textContent = message

    // ヘッダーに追加
    const headerElement = document.querySelector('.memo-main-header')
    if (headerElement) {
      headerElement.appendChild(statusElement)

      // 一定時間後に削除（savingの場合は削除しない）
      if (type !== 'saving') {
        setTimeout(() => {
          if (statusElement && statusElement.parentNode) {
            statusElement.remove()
          }
        }, 3000)
      }
    }
  }
} 
 