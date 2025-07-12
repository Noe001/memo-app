import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "memoList", "memoItem", "swipeIndicator"]
  static values = {
    swipeThreshold: { type: Number, default: 50 },
    touchSensitivity: { type: Number, default: 10 }
  }

  connect() {
    this.initializeMobileFeatures()
    this.setupTouchEvents()
    this.setupPullToRefresh()
    this.detectMobileDevice()
    console.log("Mobile touch controller connected")
  }

  disconnect() {
    this.removeTouchEvents()
  }

  // モバイル機能の初期化
  initializeMobileFeatures() {
    // PWA対応
    if ('serviceWorker' in navigator) {
      this.registerServiceWorker()
    }

    // ビューポート設定
    this.optimizeViewport()

    // モバイル固有の設定
    this.setupMobileOptimizations()
  }

  // タッチイベントの設定
  setupTouchEvents() {
    this.startX = 0
    this.startY = 0
    this.currentX = 0
    this.currentY = 0
    this.isMoving = false
    this.swipeDirection = null

    // サイドバーのスワイプ操作
    if (this.hasSidebarTarget) {
      this.sidebarTarget.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: false })
      this.sidebarTarget.addEventListener('touchmove', this.handleTouchMove.bind(this), { passive: false })
      this.sidebarTarget.addEventListener('touchend', this.handleTouchEnd.bind(this), { passive: false })
    }

    // メモリストのスワイプ操作
    if (this.hasMemoListTarget) {
      this.memoListTarget.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: false })
      this.memoListTarget.addEventListener('touchmove', this.handleTouchMove.bind(this), { passive: false })
      this.memoListTarget.addEventListener('touchend', this.handleTouchEnd.bind(this), { passive: false })
    }

    // 個別メモアイテムのスワイプ操作
    this.memoItemTargets.forEach(item => {
      item.addEventListener('touchstart', this.handleMemoTouchStart.bind(this), { passive: false })
      item.addEventListener('touchmove', this.handleMemoTouchMove.bind(this), { passive: false })
      item.addEventListener('touchend', this.handleMemoTouchEnd.bind(this), { passive: false })
    })

    // グローバルスワイプ操作
    document.addEventListener('touchstart', this.handleGlobalTouchStart.bind(this), { passive: false })
    document.addEventListener('touchmove', this.handleGlobalTouchMove.bind(this), { passive: false })
    document.addEventListener('touchend', this.handleGlobalTouchEnd.bind(this), { passive: false })
  }

  // タッチイベントの削除
  removeTouchEvents() {
    if (this.hasSidebarTarget) {
      this.sidebarTarget.removeEventListener('touchstart', this.handleTouchStart.bind(this))
      this.sidebarTarget.removeEventListener('touchmove', this.handleTouchMove.bind(this))
      this.sidebarTarget.removeEventListener('touchend', this.handleTouchEnd.bind(this))
    }

    if (this.hasMemoListTarget) {
      this.memoListTarget.removeEventListener('touchstart', this.handleTouchStart.bind(this))
      this.memoListTarget.removeEventListener('touchmove', this.handleTouchMove.bind(this))
      this.memoListTarget.removeEventListener('touchend', this.handleTouchEnd.bind(this))
    }

    this.memoItemTargets.forEach(item => {
      item.removeEventListener('touchstart', this.handleMemoTouchStart.bind(this))
      item.removeEventListener('touchmove', this.handleMemoTouchMove.bind(this))
      item.removeEventListener('touchend', this.handleMemoTouchEnd.bind(this))
    })

    document.removeEventListener('touchstart', this.handleGlobalTouchStart.bind(this))
    document.removeEventListener('touchmove', this.handleGlobalTouchMove.bind(this))
    document.removeEventListener('touchend', this.handleGlobalTouchEnd.bind(this))
  }

  // タッチ開始
  handleTouchStart(event) {
    this.startX = event.touches[0].clientX
    this.startY = event.touches[0].clientY
    this.currentX = this.startX
    this.currentY = this.startY
    this.isMoving = false
    this.swipeDirection = null
  }

  // タッチ移動
  handleTouchMove(event) {
    if (!this.startX || !this.startY) return

    this.currentX = event.touches[0].clientX
    this.currentY = event.touches[0].clientY

    const deltaX = this.currentX - this.startX
    const deltaY = this.currentY - this.startY

    // スワイプの方向を判定
    if (Math.abs(deltaX) > Math.abs(deltaY)) {
      this.swipeDirection = deltaX > 0 ? 'right' : 'left'
    } else {
      this.swipeDirection = deltaY > 0 ? 'down' : 'up'
    }

    // 移動量がしきい値を超えた場合
    if (Math.abs(deltaX) > this.touchSensitivityValue || Math.abs(deltaY) > this.touchSensitivityValue) {
      this.isMoving = true
      this.showSwipeIndicator(this.swipeDirection)
    }
  }

  // タッチ終了
  handleTouchEnd(event) {
    if (!this.startX || !this.startY) return

    const deltaX = this.currentX - this.startX
    const deltaY = this.currentY - this.startY

    // スワイプジェスチャーの判定
    if (this.isMoving && Math.abs(deltaX) > this.swipeThresholdValue) {
      this.handleSwipeGesture(this.swipeDirection, Math.abs(deltaX))
    }

    // リセット
    this.startX = 0
    this.startY = 0
    this.currentX = 0
    this.currentY = 0
    this.isMoving = false
    this.swipeDirection = null
    this.hideSwipeIndicator()
  }

  // メモアイテムのタッチ開始
  handleMemoTouchStart(event) {
    const memoItem = event.currentTarget
    memoItem.startX = event.touches[0].clientX
    memoItem.startY = event.touches[0].clientY
    memoItem.startTime = Date.now()
  }

  // メモアイテムのタッチ移動
  handleMemoTouchMove(event) {
    const memoItem = event.currentTarget
    if (!memoItem.startX) return

    const deltaX = event.touches[0].clientX - memoItem.startX
    const deltaY = event.touches[0].clientY - memoItem.startY

    // 横スワイプの場合、メモの操作を表示
    if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 30) {
      this.showMemoActions(memoItem, deltaX > 0 ? 'right' : 'left')
    }
  }

  // メモアイテムのタッチ終了
  handleMemoTouchEnd(event) {
    const memoItem = event.currentTarget
    if (!memoItem.startX) return

    const deltaX = event.touches[0].clientX - memoItem.startX
    const deltaY = event.touches[0].clientY - memoItem.startY
    const duration = Date.now() - memoItem.startTime

    // 長押し判定
    if (duration > 500 && Math.abs(deltaX) < 10 && Math.abs(deltaY) < 10) {
      this.handleLongPress(memoItem)
    }

    // スワイプ判定
    if (Math.abs(deltaX) > this.swipeThresholdValue) {
      this.handleMemoSwipe(memoItem, deltaX > 0 ? 'right' : 'left')
    }

    // リセット
    memoItem.startX = 0
    memoItem.startY = 0
    memoItem.startTime = 0
    this.hideMemoActions(memoItem)
  }

  // グローバルタッチ開始
  handleGlobalTouchStart(event) {
    this.globalStartX = event.touches[0].clientX
    this.globalStartY = event.touches[0].clientY
  }

  // グローバルタッチ移動
  handleGlobalTouchMove(event) {
    if (!this.globalStartX) return

    const deltaX = event.touches[0].clientX - this.globalStartX
    const deltaY = event.touches[0].clientY - this.globalStartY

    // 画面端からのスワイプでサイドバー操作
    if (this.globalStartX < 20 && deltaX > 50) {
      this.openSidebar()
    }
  }

  // グローバルタッチ終了
  handleGlobalTouchEnd(event) {
    this.globalStartX = 0
    this.globalStartY = 0
  }

  // スワイプジェスチャーの処理
  handleSwipeGesture(direction, distance) {
    switch (direction) {
      case 'right':
        if (distance > 100) {
          this.openSidebar()
        }
        break
      case 'left':
        if (distance > 100) {
          this.closeSidebar()
        }
        break
      case 'up':
        if (distance > 100) {
          this.scrollToTop()
        }
        break
      case 'down':
        if (distance > 100) {
          this.pullToRefresh()
        }
        break
    }
  }

  // メモのスワイプ処理
  handleMemoSwipe(memoItem, direction) {
    const memoId = memoItem.dataset.memoId

    switch (direction) {
      case 'right':
        // 右スワイプ: メモを編集
        this.editMemo(memoId)
        break
      case 'left':
        // 左スワイプ: メモを削除
        this.showDeleteConfirmation(memoItem, memoId)
        break
    }
  }

  // 長押し処理
  handleLongPress(memoItem) {
    // バイブレーション
    if (navigator.vibrate) {
      navigator.vibrate(50)
    }

    // コンテキストメニューを表示
    this.showContextMenu(memoItem)
  }

  // サイドバーを開く
  openSidebar() {
    if (this.hasSidebarTarget) {
      this.sidebarTarget.classList.add('active')
      document.body.style.overflow = 'hidden'
    }
  }

  // サイドバーを閉じる
  closeSidebar() {
    if (this.hasSidebarTarget) {
      this.sidebarTarget.classList.remove('active')
      document.body.style.overflow = ''
    }
  }

  // スワイプインジケーターを表示
  showSwipeIndicator(direction) {
    if (this.hasSwipeIndicatorTarget) {
      this.swipeIndicatorTarget.className = `swipe-indicator ${direction} active`
    }
  }

  // スワイプインジケーターを非表示
  hideSwipeIndicator() {
    if (this.hasSwipeIndicatorTarget) {
      this.swipeIndicatorTarget.classList.remove('active')
    }
  }

  // メモアクションを表示
  showMemoActions(memoItem, direction) {
    const actions = memoItem.querySelector('.memo-actions')
    if (actions) {
      actions.style.display = 'flex'
      actions.style.opacity = '1'
      actions.style.transform = `translateX(${direction === 'right' ? '0' : '-100%'})`
    }
  }

  // メモアクションを非表示
  hideMemoActions(memoItem) {
    const actions = memoItem.querySelector('.memo-actions')
    if (actions) {
      actions.style.opacity = '0'
      actions.style.transform = 'translateX(0)'
      setTimeout(() => {
        actions.style.display = 'none'
      }, 200)
    }
  }

  // プルツーリフレッシュの設定
  setupPullToRefresh() {
    let startY = 0
    let isPulling = false

    document.addEventListener('touchstart', (e) => {
      if (window.scrollY === 0) {
        startY = e.touches[0].clientY
        isPulling = false
      }
    })

    document.addEventListener('touchmove', (e) => {
      if (window.scrollY === 0 && startY > 0) {
        const deltaY = e.touches[0].clientY - startY
        if (deltaY > 50) {
          isPulling = true
          this.showPullIndicator()
        }
      }
    })

    document.addEventListener('touchend', (e) => {
      if (isPulling) {
        this.triggerRefresh()
        isPulling = false
        startY = 0
      }
    })
  }

  // プルインジケーターを表示
  showPullIndicator() {
    let indicator = document.querySelector('.pull-to-refresh-indicator')
    if (!indicator) {
      indicator = document.createElement('div')
      indicator.className = 'pull-to-refresh-indicator'
      indicator.innerHTML = '↓'
      document.body.appendChild(indicator)
    }
    indicator.style.display = 'flex'
  }

  // リフレッシュを実行
  triggerRefresh() {
    const indicator = document.querySelector('.pull-to-refresh-indicator')
    if (indicator) {
      indicator.innerHTML = '↻'
      indicator.classList.add('refreshing')
    }

    // ページをリロード
    setTimeout(() => {
      window.location.reload()
    }, 1000)
  }

  // モバイルデバイスの検出
  detectMobileDevice() {
    const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
    if (isMobile) {
      document.body.classList.add('mobile-device')
    }

    // タッチデバイスの検出
    const isTouchDevice = ('ontouchstart' in window) || (navigator.maxTouchPoints > 0)
    if (isTouchDevice) {
      document.body.classList.add('touch-device')
    }
  }

  // ビューポート最適化
  optimizeViewport() {
    // ズーム防止
    const viewportMeta = document.querySelector('meta[name="viewport"]')
    if (viewportMeta) {
      viewportMeta.content = 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no'
    }

    // 100vh問題の対応
    const setViewportHeight = () => {
      const vh = window.innerHeight * 0.01
      document.documentElement.style.setProperty('--vh', `${vh}px`)
    }
    setViewportHeight()
    window.addEventListener('resize', setViewportHeight)
  }

  // モバイル最適化設定
  setupMobileOptimizations() {
    // タップハイライト無効化
    document.addEventListener('touchstart', (e) => {
      if (e.target.matches('button, a, .clickable')) {
        e.target.style.webkitTapHighlightColor = 'transparent'
      }
    })

    // スクロール改善
    document.body.style.webkitOverflowScrolling = 'touch'

    // フォーカス時のズーム防止
    const inputs = document.querySelectorAll('input, textarea')
    inputs.forEach(input => {
      input.addEventListener('focus', () => {
        input.style.fontSize = '16px'
      })
    })
  }

  // Service Worker登録
  registerServiceWorker() {
    navigator.serviceWorker.register('/service-worker.js')
      .then(registration => {
        console.log('Service Worker registered:', registration)
      })
      .catch(error => {
        console.log('Service Worker registration failed:', error)
      })
  }

  // トップにスクロール
  scrollToTop() {
    window.scrollTo({
      top: 0,
      behavior: 'smooth'
    })
  }

  // メモ編集
  editMemo(memoId) {
    const memoLink = document.querySelector(`[data-memo-id="${memoId}"]`)
    if (memoLink) {
      memoLink.click()
    }
  }

  // 削除確認
  showDeleteConfirmation(memoItem, memoId) {
    const confirmation = confirm('このメモを削除しますか？')
    if (confirmation) {
      this.deleteMemo(memoId)
    }
  }

  // メモ削除
  deleteMemo(memoId) {
    const deleteButton = document.querySelector(`[data-memo-id="${memoId}"] .delete-memo-btn`)
    if (deleteButton) {
      deleteButton.click()
    }
  }

  // コンテキストメニュー表示
  showContextMenu(memoItem) {
    // 実装予定: コンテキストメニューの表示
    console.log('Context menu for memo:', memoItem.dataset.memoId)
  }

  // トップに戻る
  scrollToTop() {
    window.scrollTo({
      top: 0,
      behavior: 'smooth'
    })
  }
} 
