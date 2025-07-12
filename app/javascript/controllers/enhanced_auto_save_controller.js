import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    url: String,
    supabaseUrl: String,
    supabaseKey: String,
    userId: String,
    memoId: String
  }
  static targets = ["status", "conflictModal", "conflictMessage"]

  connect() {
    this.saveTimeout = null
    this.isNewRecord = this.element.action.includes('/memos') && !this.element.action.match(/\/memos\/\d+/)
    this.memoId = this.memoIdValue || null
    this.lastSavedVersion = null
    
    // Supabase クライアントを初期化
    this.initializeSupabase()
    
    // リアルタイム機能を初期化
    this.initializeRealtimeFeatures()
    
    // プレゼンス機能との連携
    this.setupPresenceIntegration()
    
    // 新規作成時の初期チェック
    if (this.isNewRecord) {
      this.checkInitialContent()
    }
  }

  disconnect() {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
    }
    
    this.cleanupRealtimeConnections()
  }

  initializeSupabase() {
    // CDNからSupabaseを使用
    if (typeof window.supabase !== 'undefined') {
      this.supabase = window.supabase.createClient(
        this.supabaseUrlValue || 'http://127.0.0.1:54321',
        this.supabaseKeyValue || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
      )
    } else {
      console.warn('Supabase CDN not loaded')
    }
  }

  initializeRealtimeFeatures() {
    if (!this.memoId) return

    // メモの変更を監視
    this.realtimeSubscription = this.supabase
      .channel(`memo_changes_${this.memoId}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'memos',
          filter: `id=eq.${this.memoId}`
        },
        (payload) => {
          this.handleRealtimeUpdate(payload)
        }
      )
      .subscribe()
  }

  setupPresenceIntegration() {
    // プレゼンスコントローラーとの連携
    this.presenceController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller*="presence"]'), 
      'presence'
    )
  }

  handleRealtimeUpdate(payload) {
    const { new: newRecord, old: oldRecord } = payload
    
    // バージョンチェック
    if (this.lastSavedVersion && new Date(newRecord.updated_at) > this.lastSavedVersion) {
      // コンフリクトの可能性をチェック
      if (this.hasUnsavedChanges()) {
        this.showConflictDialog(newRecord, oldRecord)
      } else {
        // 未保存の変更がなければ、UIを更新
        this.updateFormWithRemoteChanges(newRecord)
      }
    }
  }

  hasUnsavedChanges() {
    // フォームの現在の値と最後に保存された値を比較
    const titleInput = this.element.querySelector('[name*="title"]')
    const descriptionInput = this.element.querySelector('[name*="description"]')
    const tagsInput = this.element.querySelector('[name="tags"]')
    
    return (titleInput && titleInput.value !== titleInput.defaultValue) ||
           (descriptionInput && descriptionInput.value !== descriptionInput.defaultValue) ||
           (tagsInput && tagsInput.value !== tagsInput.defaultValue)
  }

  updateFormWithRemoteChanges(memo) {
    // リモートの変更でフォームを更新
    const titleInput = this.element.querySelector('[name*="title"]')
    const descriptionInput = this.element.querySelector('[name*="description"]')
    
    if (titleInput) {
      titleInput.value = memo.title || ''
      titleInput.defaultValue = memo.title || ''
    }
    
    if (descriptionInput) {
      descriptionInput.value = memo.description || ''
      descriptionInput.defaultValue = memo.description || ''
    }
    
    this.lastSavedVersion = new Date(memo.updated_at)
    this.showSaveStatus('リモートから更新されました', 'info')
  }

  showConflictDialog(serverMemo, oldMemo) {
    if (!this.hasConflictModalTarget) return

    this.conflictMessageTarget.innerHTML = `
      <div class="conflict-dialog">
        <h3>編集競合が発生しました</h3>
        <p>他のユーザーがこのメモを変更しました。どちらの変更を保持しますか？</p>
        
        <div class="conflict-comparison">
          <div class="conflict-local">
            <h4>あなたの変更</h4>
            <div class="conflict-content">
              <strong>タイトル:</strong> ${this.getCurrentTitle()}<br>
              <strong>内容:</strong> ${this.getCurrentDescription()}
            </div>
          </div>
          
          <div class="conflict-remote">
            <h4>サーバーの変更</h4>
            <div class="conflict-content">
              <strong>タイトル:</strong> ${serverMemo.title || '無題'}<br>
              <strong>内容:</strong> ${serverMemo.description || ''}
            </div>
          </div>
        </div>
        
        <div class="conflict-actions">
          <button class="btn btn-primary" data-action="click->enhanced-auto-save#resolveConflict" data-resolution="keep-local">
            自分の変更を保持
          </button>
          <button class="btn btn-secondary" data-action="click->enhanced-auto-save#resolveConflict" data-resolution="accept-remote">
            サーバーの変更を受け入れ
          </button>
          <button class="btn btn-outline" data-action="click->enhanced-auto-save#resolveConflict" data-resolution="merge">
            手動でマージ
          </button>
        </div>
      </div>
    `
    
    this.conflictModalTarget.classList.remove('hidden')
    this.serverMemo = serverMemo
  }

  resolveConflict(event) {
    const resolution = event.target.dataset.resolution
    
    switch (resolution) {
      case 'keep-local':
        // 自分の変更を強制保存
        this.performSave(null, true)
        break
      case 'accept-remote':
        // サーバーの変更を受け入れ
        this.updateFormWithRemoteChanges(this.serverMemo)
        break
      case 'merge':
        // 手動マージモードに切り替え
        this.enableMergeMode()
        break
    }
    
    this.conflictModalTarget.classList.add('hidden')
  }

  enableMergeMode() {
    // マージモードのUIを表示
    const mergeContainer = document.createElement('div')
    mergeContainer.className = 'merge-mode-container'
    mergeContainer.innerHTML = `
      <div class="merge-mode">
        <h4>手動マージモード</h4>
        <p>両方の変更を確認して、最終的な内容を決定してください。</p>
        
        <div class="merge-fields">
          <div class="merge-field">
            <label>タイトル（あなたの変更）</label>
            <input type="text" class="local-title" value="${this.getCurrentTitle()}">
          </div>
          
          <div class="merge-field">
            <label>タイトル（サーバーの変更）</label>
            <input type="text" class="remote-title" value="${this.serverMemo.title || ''}" readonly>
          </div>
          
          <div class="merge-field">
            <label>内容（あなたの変更）</label>
            <textarea class="local-description">${this.getCurrentDescription()}</textarea>
          </div>
          
          <div class="merge-field">
            <label>内容（サーバーの変更）</label>
            <textarea class="remote-description" readonly>${this.serverMemo.description || ''}</textarea>
          </div>
        </div>
        
        <div class="merge-actions">
          <button class="btn btn-primary" data-action="click->enhanced-auto-save#completeMerge">
            マージ完了
          </button>
          <button class="btn btn-secondary" data-action="click->enhanced-auto-save#cancelMerge">
            キャンセル
          </button>
        </div>
      </div>
    `
    
    this.element.appendChild(mergeContainer)
  }

  completeMerge(event) {
    const container = event.target.closest('.merge-mode-container')
    const localTitle = container.querySelector('.local-title').value
    const localDescription = container.querySelector('.local-description').value
    
    // フォームを更新
    const titleInput = this.element.querySelector('[name*="title"]')
    const descriptionInput = this.element.querySelector('[name*="description"]')
    
    if (titleInput) titleInput.value = localTitle
    if (descriptionInput) descriptionInput.value = localDescription
    
    // マージ完了後に保存
    this.performSave(null, true)
    
    // マージUIを削除
    container.remove()
  }

  cancelMerge(event) {
    const container = event.target.closest('.merge-mode-container')
    container.remove()
  }

  getCurrentTitle() {
    const titleInput = this.element.querySelector('[name*="title"]')
    return titleInput ? titleInput.value : ''
  }

  getCurrentDescription() {
    const descriptionInput = this.element.querySelector('[name*="description"]')
    return descriptionInput ? descriptionInput.value : ''
  }

  // フィールドが変更された時の処理（拡張版）
  saveField(event) {
    // プレゼンス状態を更新
    if (this.presenceController) {
      this.presenceController.startEditing()
    }
    
    // 入力イベント以外（blur など）は無視
    if (event.type !== 'input') {
      if (this.presenceController) {
        this.presenceController.stopEditing()
      }
      return
    }

    // デバウンス処理
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
    }

    this.saveTimeout = setTimeout(() => {
      this.performSave(event.target)
    }, 1000) // 1秒後に保存
  }

  // 実際の保存処理（拡張版）
  async performSave(changedField, forceOverwrite = false) {
    const formData = new FormData(this.element)
    
    // バージョン情報を追加（競合検出用）
    if (this.lastSavedVersion && !forceOverwrite) {
      formData.append('client_version', this.lastSavedVersion.toISOString())
    }
    
    // 新規作成の場合の処理
    if (this.isNewRecord) {
      const title = formData.get('memo[title]') || formData.get('memo_to_add[title]')
      const description = formData.get('memo[description]') || formData.get('memo_to_add[description]')
      const tags = formData.get('tags')
      
      const hasContent = (title && title.trim()) || 
                        (description && description.trim()) || 
                        (tags && tags.trim())
      
      if (!hasContent) {
        return
      }
      
      if (!this.memoId) {
        await this.createNewMemo(formData)
        return
      }
    }

    // 既存メモの更新
    this.updateMemo(formData, forceOverwrite)
  }

  // 新規メモの作成（拡張版）
  async createNewMemo(formData) {
    this.showSaveStatus('保存中...', 'saving')
    
    try {
      const response = await fetch(this.urlValue, {
        method: 'POST',
        body: formData,
        headers: {
          'Accept': 'application/json, text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
      })

      if (response.ok) {
        const contentType = response.headers.get('content-type') || ''

        if (contentType.includes('application/json')) {
          const data = await response.json()
          if (data.memo_id) {
            this.memoId = data.memo_id
            this.memoIdValue = data.memo_id
            this.isNewRecord = false

            // URL を更新用に変更
            this.urlValue = `/memos/${this.memoId}`
            this.element.action = this.urlValue

            // リアルタイム機能を初期化
            this.initializeRealtimeFeatures()

            // 最後に保存されたバージョンを記録
            this.lastSavedVersion = new Date()

            // URL 履歴を更新
            if (window.Turbo) {
              window.Turbo.visit(`/memos/${this.memoId}`, { action: 'replace' })
            } else if (window.history && window.history.replaceState) {
              window.history.replaceState({}, '', `/memos/${this.memoId}`)
            }

            this.showSaveStatus('保存完了', 'success')
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

  // 既存メモの更新（拡張版）
  async updateMemo(formData, forceOverwrite = false) {
    this.showSaveStatus('保存中...', 'saving')
    
    try {
      const response = await fetch(this.urlValue, {
        method: 'PATCH',
        body: formData,
        headers: {
          'Accept': 'application/json, text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
          'X-Force-Overwrite': forceOverwrite ? 'true' : 'false'
        }
      })

      if (response.ok) {
        const contentType = response.headers.get('content-type')
        
        if (contentType && contentType.includes('application/json')) {
          const data = await response.json()
          
          if (data.conflict_detected) {
            // サーバーサイドでコンフリクトが検出された
            this.handleServerConflict(data)
          } else {
            // 正常に保存完了
            this.lastSavedVersion = new Date(data.updated_at || new Date())
            this.showSaveStatus('保存完了', 'success')
          }
        } else if (contentType && contentType.includes('turbo-stream')) {
          // Turbo Stream処理
          const html = await response.text()
          const tempDiv = document.createElement('div')
          tempDiv.innerHTML = html
          
          const turboStreamElements = tempDiv.querySelectorAll('turbo-stream')
          turboStreamElements.forEach(element => {
            if (window.Turbo) {
              window.Turbo.renderStreamMessage(element.outerHTML)
            }
          })
          
          this.lastSavedVersion = new Date()
          this.showSaveStatus('保存完了', 'success')
        }
      } else if (response.status === 409) {
        // コンフリクトエラー
        const data = await response.json()
        this.handleServerConflict(data)
      } else {
        this.showSaveStatus('保存に失敗しました', 'error')
      }
    } catch (error) {
      console.error('Update error:', error)
      this.showSaveStatus('保存に失敗しました', 'error')
    }
  }

  handleServerConflict(data) {
    this.showConflictDialog(data.server_memo, data.client_memo)
  }

  showSaveStatus(message, type) {
    const existingStatus = document.querySelector('.auto-save-status')

    if (type === 'success') {
      if (existingStatus) existingStatus.remove()
      return
    }

    if (existingStatus) existingStatus.remove()

    const statusElement = document.createElement('div')
    statusElement.className = `auto-save-status auto-save-status-${type}`
    statusElement.textContent = message

    const headerElement = document.querySelector('.memo-main-header')
    if (headerElement) {
      headerElement.appendChild(statusElement)

      if (type === 'error') {
        setTimeout(() => {
          statusElement.remove()
        }, 3000)
      }
    }
  }

  cleanupRealtimeConnections() {
    if (this.realtimeSubscription) {
      this.realtimeSubscription.unsubscribe()
    }
  }

  checkInitialContent() {
    const titleField = this.element.querySelector('[name$="[title]"]')
    const descriptionField = this.element.querySelector('[name$="[description]"]')
    const tagsField = this.element.querySelector('[name="tags"]')
    
    const hasTitle = titleField && titleField.value.trim()
    const hasDescription = descriptionField && descriptionField.value.trim()
    const hasTags = tagsField && tagsField.value.trim()
    
    this.hasContent = hasTitle || hasDescription || hasTags
  }
} 
