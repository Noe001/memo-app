import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["directionBtn", "directionField", "sortSelect"]
  static values = { 
    currentSortBy: String,
    currentDirection: String
  }

  connect() {
    this.updateButtonDisplay()
  }

  toggleDirection() {
    // 現在の方向を切り替え
    const newDirection = this.currentDirectionValue === 'asc' ? 'desc' : 'asc'
    
    // 隠しフィールドの値を更新
    this.directionFieldTarget.value = newDirection
    
    // ボタンの表示を更新
    this.currentDirectionValue = newDirection
    this.updateButtonDisplay()
    
    // フォームを自動送信
    this.submitForm()
  }

  updateButtonDisplay() {
    const btn = this.directionBtnTarget
    const text = btn.querySelector('.sort-direction-text')
    const isAsc = this.currentDirectionValue === 'asc'
    
    // ボタンのテキストとタイトルを更新
    text.textContent = isAsc ? '昇順' : '降順'
    btn.title = isAsc ? '降順に変更' : '昇順に変更'
    
    // アイコンの向きを視覚的に示すためのクラス切り替え（必要に応じて）
    btn.classList.toggle('sort-asc', isAsc)
    btn.classList.toggle('sort-desc', !isAsc)
  }

  submitForm() {
    const form = this.element.closest('form')
    if (form) {
      // 少し遅延させてから送信
      setTimeout(() => {
        form.submit()
      }, 100)
    }
  }

  // 現在の並べ替え方法が変更された時の処理
  currentSortByValueChanged() {
    this.updateButtonDisplay()
  }

  // 現在の方向が変更された時の処理
  currentDirectionValueChanged() {
    this.updateButtonDisplay()
  }
} 
