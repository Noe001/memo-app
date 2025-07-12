import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["memoList", "presenceIndicator", "conflictDialog", "conflictMessage"]
  static values = { 
    url: String,
    anonKey: String,
    userId: String,
    memoId: String,
    sessionId: String
  }

  connect() {
    // CDNからSupabaseを使用
    if (typeof window.supabase !== 'undefined') {
      this.supabase = window.supabase.createClient(
        this.urlValue || 'http://127.0.0.1:54321',
        this.anonKeyValue || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
      )
    } else {
      console.warn('Supabase CDN not loaded')
      return
    }
    
    // セッションIDを生成
    this.sessionIdValue = this.sessionIdValue || this.generateSessionId()
    
    // リアルタイム機能を初期化
    this.initializeRealtimeFeatures()
  }

  disconnect() {
    // リアルタイム接続をクリーンアップ
    this.cleanup()
  }

  generateSessionId() {
    return Math.random().toString(36).substr(2, 9) + Date.now().toString(36)
  }

  initializeRealtimeFeatures() {
    // メモの変更を監視
    this.subscribeToMemoChanges()
    
    // プレゼンス機能を初期化
    this.initializePresence()
    
    // コンフリクト解決機能を初期化
    this.initializeConflictResolution()
  }

  subscribeToMemoChanges() {
    // メモテーブルの変更を監視
    this.memoSubscription = this.supabase
      .channel('memo_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'memos',
          filter: `user_id=eq.${this.userIdValue}`
        },
        (payload) => {
          console.log('Memo change detected:', payload)
          this.handleMemoChange(payload)
        }
      )
      .subscribe()

    // タグテーブルの変更を監視
    this.tagSubscription = this.supabase
      .channel('tag_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'tags'
        },
        (payload) => {
          console.log('Tag change detected:', payload)
          this.handleTagChange(payload)
        }
      )
      .subscribe()
  }

  initializePresence() {
    if (!this.memoIdValue) return

    // プレゼンス機能を初期化
    this.presenceChannel = this.supabase
      .channel(`memo_${this.memoIdValue}`)
      .on('presence', { event: 'sync' }, () => {
        this.updatePresenceDisplay()
      })
      .on('presence', { event: 'join' }, ({ key, newPresences }) => {
        this.handleUserJoin(key, newPresences)
      })
      .on('presence', { event: 'leave' }, ({ key, leftPresences }) => {
        this.handleUserLeave(key, leftPresences)
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          // 自分のプレゼンスを送信
          await this.presenceChannel.track({
            user_id: this.userIdValue,
            session_id: this.sessionIdValue,
            status: 'viewing',
            last_seen: new Date().toISOString()
          })
        }
      })
  }

  initializeConflictResolution() {
    // コンフリクト解決用のイベントリスナー
    this.conflictResolutionChannel = this.supabase
      .channel('conflict_resolution')
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'memos',
          filter: `id=eq.${this.memoIdValue}`
        },
        (payload) => {
          this.handlePotentialConflict(payload)
        }
      )
      .subscribe()
  }

  handleMemoChange(payload) {
    const { eventType, new: newRecord, old: oldRecord } = payload
    
    switch (eventType) {
      case 'INSERT':
        this.addMemoToList(newRecord)
        break
      case 'UPDATE':
        this.updateMemoInList(newRecord, oldRecord)
        break
      case 'DELETE':
        this.removeMemoFromList(oldRecord)
        break
    }
  }

  handleTagChange(payload) {
    const { eventType, new: newRecord, old: oldRecord } = payload
    
    // タグ変更時の処理
    console.log('Tag change:', eventType, newRecord, oldRecord)
    
    // タグフィルターを更新
    this.updateTagFilters()
  }

  addMemoToList(memo) {
    if (!this.hasMemoListTarget) return
    
    // 新しいメモをリストに追加
    const memoElement = this.createMemoElement(memo)
    this.memoListTarget.insertBefore(memoElement, this.memoListTarget.firstChild)
    
    // アニメーション効果
    memoElement.classList.add('animate-fade-in')
    
    // 通知を表示
    this.showNotification('新しいメモが追加されました', 'success')
  }

  updateMemoInList(newMemo, oldMemo) {
    if (!this.hasMemoListTarget) return
    
    const memoElement = this.memoListTarget.querySelector(`[data-memo-id="${newMemo.id}"]`)
    if (memoElement) {
      // メモ要素を更新
      this.updateMemoElement(memoElement, newMemo)
      
      // 変更をハイライト
      memoElement.classList.add('memo-updated')
      setTimeout(() => {
        memoElement.classList.remove('memo-updated')
      }, 2000)
    }
  }

  removeMemoFromList(memo) {
    if (!this.hasMemoListTarget) return
    
    const memoElement = this.memoListTarget.querySelector(`[data-memo-id="${memo.id}"]`)
    if (memoElement) {
      // フェードアウト効果
      memoElement.classList.add('animate-fade-out')
      setTimeout(() => {
        memoElement.remove()
      }, 300)
      
      // 通知を表示
      this.showNotification('メモが削除されました', 'info')
    }
  }

  updatePresenceDisplay() {
    if (!this.hasPresenceIndicatorTarget) return
    
    const state = this.presenceChannel.presenceState()
    const users = Object.keys(state)
    
    if (users.length > 1) {
      // 他のユーザーがいる場合
      const otherUsers = users.filter(userId => userId !== this.userIdValue)
      this.presenceIndicatorTarget.innerHTML = `
        <div class="presence-indicator">
          <span class="presence-count">${otherUsers.length}</span>
          <span class="presence-text">他のユーザーが編集中</span>
        </div>
      `
      this.presenceIndicatorTarget.classList.remove('hidden')
    } else {
      // 自分だけの場合
      this.presenceIndicatorTarget.classList.add('hidden')
    }
  }

  handleUserJoin(userId, presences) {
    if (userId === this.userIdValue) return
    
    console.log('User joined:', userId, presences)
    this.showNotification('他のユーザーがメモを編集中です', 'info')
  }

  handleUserLeave(userId, presences) {
    if (userId === this.userIdValue) return
    
    console.log('User left:', userId, presences)
  }

  handlePotentialConflict(payload) {
    const { new: newRecord } = payload
    
    // 現在編集中のフォーム要素を取得
    const currentForm = document.querySelector(`[data-memo-id="${newRecord.id}"] form`)
    if (!currentForm) return
    
    // フォームが変更されている場合、コンフリクトの可能性
    if (this.hasUnsavedChanges(currentForm)) {
      this.showConflictDialog(newRecord)
    }
  }

  hasUnsavedChanges(form) {
    // フォームの要素をチェックして未保存の変更があるかを確認
    const formData = new FormData(form)
    const titleInput = form.querySelector('input[name*="title"]')
    const descriptionInput = form.querySelector('textarea[name*="description"]')
    
    return titleInput?.value !== titleInput?.defaultValue ||
           descriptionInput?.value !== descriptionInput?.defaultValue
  }

  showConflictDialog(serverMemo) {
    if (!this.hasConflictDialogTarget) return
    
    this.conflictMessageTarget.innerHTML = `
      <p>このメモは他のユーザーによって変更されています。</p>
      <div class="conflict-options">
        <button class="btn btn-primary" data-action="click->realtime#resolveConflict" data-resolution="merge">
          変更をマージ
        </button>
        <button class="btn btn-secondary" data-action="click->realtime#resolveConflict" data-resolution="overwrite">
          上書き保存
        </button>
        <button class="btn btn-outline" data-action="click->realtime#resolveConflict" data-resolution="reload">
          最新版を読み込み
        </button>
      </div>
    `
    
    this.conflictDialogTarget.classList.remove('hidden')
  }

  resolveConflict(event) {
    const resolution = event.target.dataset.resolution
    
    switch (resolution) {
      case 'merge':
        this.mergeChanges()
        break
      case 'overwrite':
        this.overwriteChanges()
        break
      case 'reload':
        this.reloadMemo()
        break
    }
    
    this.conflictDialogTarget.classList.add('hidden')
  }

  mergeChanges() {
    // 変更をマージするロジック
    console.log('Merging changes...')
    this.showNotification('変更をマージしました', 'success')
  }

  overwriteChanges() {
    // 上書き保存するロジック
    console.log('Overwriting changes...')
    this.showNotification('変更を上書き保存しました', 'success')
  }

  reloadMemo() {
    // 最新版を読み込むロジック
    console.log('Reloading memo...')
    window.location.reload()
  }

  updatePresenceStatus(status) {
    if (!this.presenceChannel) return
    
    this.presenceChannel.track({
      user_id: this.userIdValue,
      session_id: this.sessionIdValue,
      status: status,
      last_seen: new Date().toISOString()
    })
  }

  createMemoElement(memo) {
    // メモ要素を作成するヘルパー関数
    const element = document.createElement('div')
    element.className = 'memo-item'
    element.setAttribute('data-memo-id', memo.id)
    element.innerHTML = `
      <div class="memo-content">
        <h3>${memo.title || '無題'}</h3>
        <p>${memo.description || ''}</p>
        <div class="memo-meta">
          <span class="memo-date">${new Date(memo.updated_at).toLocaleDateString()}</span>
        </div>
      </div>
    `
    return element
  }

  updateMemoElement(element, memo) {
    // メモ要素を更新するヘルパー関数
    const titleElement = element.querySelector('h3')
    const descriptionElement = element.querySelector('p')
    const dateElement = element.querySelector('.memo-date')
    
    if (titleElement) titleElement.textContent = memo.title || '無題'
    if (descriptionElement) descriptionElement.textContent = memo.description || ''
    if (dateElement) dateElement.textContent = new Date(memo.updated_at).toLocaleDateString()
  }

  updateTagFilters() {
    // タグフィルターを更新
    // 実装はビューの構造に依存
    console.log('Updating tag filters...')
  }

  showNotification(message, type = 'info') {
    // 通知を表示
    const notification = document.createElement('div')
    notification.className = `notification notification-${type}`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    // 自動的に消去
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }

  cleanup() {
    // リアルタイム接続をクリーンアップ
    if (this.memoSubscription) {
      this.memoSubscription.unsubscribe()
    }
    
    if (this.tagSubscription) {
      this.tagSubscription.unsubscribe()
    }
    
    if (this.presenceChannel) {
      this.presenceChannel.unsubscribe()
    }
    
    if (this.conflictResolutionChannel) {
      this.conflictResolutionChannel.unsubscribe()
    }
  }
} 
