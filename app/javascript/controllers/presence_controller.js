import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator", "userList"]
  static values = { 
    url: String,
    anonKey: String,
    userId: String,
    memoId: String,
    userName: String
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
    this.sessionId = this.generateSessionId()
    
    // プレゼンス機能を初期化
    this.initializePresence()
  }

  disconnect() {
    // プレゼンス接続をクリーンアップ
    this.cleanup()
  }

  generateSessionId() {
    return Math.random().toString(36).substr(2, 9) + Date.now().toString(36)
  }

  initializePresence() {
    if (!this.memoIdValue) return

    // プレゼンスチャンネルを作成
    this.presenceChannel = this.supabase
      .channel(`presence_memo_${this.memoIdValue}`)
      .on('presence', { event: 'sync' }, () => {
        console.log('Presence synced')
        this.updatePresenceDisplay()
      })
      .on('presence', { event: 'join' }, ({ key, newPresences }) => {
        console.log('User joined:', key, newPresences)
        this.handleUserJoin(key, newPresences)
      })
      .on('presence', { event: 'leave' }, ({ key, leftPresences }) => {
        console.log('User left:', key, leftPresences)
        this.handleUserLeave(key, leftPresences)
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          console.log('Presence subscribed')
          // 自分のプレゼンスを送信
          await this.presenceChannel.track({
            user_id: this.userIdValue,
            user_name: this.userNameValue,
            session_id: this.sessionId,
            status: 'viewing',
            last_seen: new Date().toISOString(),
            memo_id: this.memoIdValue
          })
        }
      })
  }

  updatePresenceDisplay() {
    if (!this.hasIndicatorTarget) return
    
    const state = this.presenceChannel.presenceState()
    const allUsers = Object.values(state).flat()
    
    // 自分以外のユーザーを取得
    const otherUsers = allUsers.filter(user => user.user_id !== this.userIdValue)
    
    if (otherUsers.length > 0) {
      this.showPresenceIndicator(otherUsers)
    } else {
      this.hidePresenceIndicator()
    }
  }

  showPresenceIndicator(users) {
    const userCount = users.length
    const userNames = users.map(user => user.user_name).join(', ')
    
    this.indicatorTarget.innerHTML = `
      <div class="presence-indicator active">
        <div class="presence-avatars">
          ${users.map(user => `
            <div class="presence-avatar" title="${user.user_name}">
              <span class="avatar-initial">${user.user_name.charAt(0).toUpperCase()}</span>
              <span class="presence-status ${user.status}"></span>
            </div>
          `).join('')}
        </div>
        <div class="presence-text">
          <span class="user-count">${userCount}</span>
          <span class="user-label">${userCount === 1 ? 'ユーザー' : 'ユーザー'}が編集中</span>
        </div>
      </div>
    `
    
    this.indicatorTarget.classList.remove('hidden')
    
    // ユーザーリストも更新
    if (this.hasUserListTarget) {
      this.updateUserList(users)
    }
  }

  hidePresenceIndicator() {
    this.indicatorTarget.classList.add('hidden')
    
    if (this.hasUserListTarget) {
      this.userListTarget.innerHTML = ''
    }
  }

  updateUserList(users) {
    this.userListTarget.innerHTML = `
      <div class="presence-user-list">
        <h4>現在編集中のユーザー</h4>
        <ul>
          ${users.map(user => `
            <li class="presence-user-item">
              <div class="user-avatar">
                <span class="avatar-initial">${user.user_name.charAt(0).toUpperCase()}</span>
                <span class="presence-status ${user.status}"></span>
              </div>
              <div class="user-info">
                <span class="user-name">${user.user_name}</span>
                <span class="user-status">${this.getStatusLabel(user.status)}</span>
              </div>
            </li>
          `).join('')}
        </ul>
      </div>
    `
  }

  getStatusLabel(status) {
    switch (status) {
      case 'editing':
        return '編集中'
      case 'viewing':
        return '閲覧中'
      case 'idle':
        return '待機中'
      default:
        return 'オンライン'
    }
  }

  handleUserJoin(userId, presences) {
    // ユーザーが参加した時の処理
    const user = presences[0]
    if (user && user.user_id !== this.userIdValue) {
      this.showNotification(`${user.user_name}さんがメモを編集中です`, 'info')
    }
  }

  handleUserLeave(userId, presences) {
    // ユーザーが離脱した時の処理
    const user = presences[0]
    if (user && user.user_id !== this.userIdValue) {
      this.showNotification(`${user.user_name}さんが編集を終了しました`, 'info')
    }
  }

  updateStatus(status) {
    if (!this.presenceChannel) return
    
    console.log('Updating presence status:', status)
    
    this.presenceChannel.track({
      user_id: this.userIdValue,
      user_name: this.userNameValue,
      session_id: this.sessionId,
      status: status,
      last_seen: new Date().toISOString(),
      memo_id: this.memoIdValue
    })
  }

  // フォームフィールドにフォーカスした時
  startEditing() {
    this.updateStatus('editing')
  }

  // フォームフィールドからフォーカスが外れた時
  stopEditing() {
    this.updateStatus('viewing')
  }

  // ページが非アクティブになった時
  setIdle() {
    this.updateStatus('idle')
  }

  showNotification(message, type = 'info') {
    // 通知を表示
    const notification = document.createElement('div')
    notification.className = `notification notification-${type} presence-notification`
    notification.innerHTML = `
      <div class="notification-content">
        <span class="notification-message">${message}</span>
        <button class="notification-close" onclick="this.parentElement.parentElement.remove()">×</button>
      </div>
    `
    
    // 通知コンテナを取得または作成
    let notificationContainer = document.querySelector('.notification-container')
    if (!notificationContainer) {
      notificationContainer = document.createElement('div')
      notificationContainer.className = 'notification-container'
      document.body.appendChild(notificationContainer)
    }
    
    notificationContainer.appendChild(notification)
    
    // 自動的に消去
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }

  cleanup() {
    if (this.presenceChannel) {
      this.presenceChannel.unsubscribe()
    }
  }
} 
