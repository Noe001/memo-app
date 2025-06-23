import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay"]
  static classes = ["active"]

  initialize() {
    this.scrollPosition = 0
  }

  // サイドバーを開く
  open() {
    this.overlayTarget.classList.add(this.activeClass)
    this.sidebarTarget.classList.add(this.activeClass)
    this.disableScroll()
  }

  // サイドバーを閉じる
  close() {
    this.overlayTarget.classList.remove(this.activeClass)
    this.sidebarTarget.classList.remove(this.activeClass)
    this.enableScroll()
  }

  // サイドバーの開閉を切り替える
  toggle() {
    if (this.sidebarTarget.classList.contains(this.activeClass)) {
      this.close()
    } else {
      this.open()
    }
  }

  // オーバーレイクリックでサイドバーを閉じる
  closeOnOverlay(event) {
    if (event.target === this.overlayTarget) {
      this.close()
    }
  }

  // スクロールを無効化（スクロールバーを維持）
  disableScroll() {
    // 現在のスクロール位置を保存
    this.scrollPosition = window.pageYOffset || document.documentElement.scrollTop
    
    // bodyを固定位置にしてスクロールを無効化
    document.body.style.position = 'fixed'
    document.body.style.top = `-${this.scrollPosition}px`
    document.body.style.width = '100%'
    document.body.style.overflowY = 'scroll' // スクロールバーを強制表示
  }

  // スクロールを有効化
  enableScroll() {
    // bodyの固定を解除
    document.body.style.position = ''
    document.body.style.top = ''
    document.body.style.width = ''
    document.body.style.overflowY = ''
    
    // 元のスクロール位置に戻す
    window.scrollTo(0, this.scrollPosition)
  }
} 
