import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["email", "password", "loginForm", "errorMessage", "supabaseSection"]
  static values = { 
    url: String,
    anonKey: String
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
    
    // 既存のセッションを確認
    this.checkExistingSession()
  }

  async checkExistingSession() {
    try {
      const { data: { session }, error } = await this.supabase.auth.getSession()
      
      if (error) {
        console.warn('Session check error:', error.message)
        return
      }
      
      if (session) {
        console.log('Existing Supabase session found, redirecting...')
        this.handleSuccessfulLogin(session.access_token)
      }
    } catch (error) {
      console.error('Error checking session:', error)
    }
  }

  async signInWithSupabase(event) {
    event.preventDefault()
    
    const email = this.emailTarget.value
    const password = this.passwordTarget.value
    
    if (!email || !password) {
      this.showError('メールアドレスとパスワードを入力してください')
      return
    }
    
    try {
      this.setLoading(true)
      this.clearError()
      
      const { data, error } = await this.supabase.auth.signInWithPassword({
        email: email,
        password: password
      })
      
      if (error) {
        if (error.message.includes('Invalid login credentials')) {
          this.showError('メールアドレスまたはパスワードが正しくありません')
        } else if (error.message.includes('Email not confirmed')) {
          this.showError('メールアドレスが確認されていません')
        } else {
          this.showError(`ログインエラー: ${error.message}`)
        }
        return
      }
      
      if (data.session) {
        console.log('Supabase login successful')
        this.handleSuccessfulLogin(data.session.access_token)
      } else {
        this.showError('ログインに失敗しました')
      }
      
    } catch (error) {
      console.error('Supabase login error:', error)
      this.showError('ログインに失敗しました。再度お試しください。')
    } finally {
      this.setLoading(false)
    }
  }

  async signUpWithSupabase(event) {
    event.preventDefault()
    
    const email = this.emailTarget.value
    const password = this.passwordTarget.value
    
    if (!email || !password) {
      this.showError('メールアドレスとパスワードを入力してください')
      return
    }
    
    if (password.length < 8) {
      this.showError('パスワードは8文字以上で入力してください')
      return
    }
    
    try {
      this.setLoading(true)
      this.clearError()
      
      const { data, error } = await this.supabase.auth.signUp({
        email: email,
        password: password,
        options: {
          data: {
            name: email.split('@')[0] // デフォルト名として@マークより前を使用
          }
        }
      })
      
      if (error) {
        this.showError(`サインアップエラー: ${error.message}`)
        return
      }
      
      if (data.user) {
        if (data.session) {
          // 即座にログイン状態になった場合
          console.log('Supabase signup and login successful')
          this.handleSuccessfulLogin(data.session.access_token)
        } else {
          // メール確認が必要な場合
          this.showSuccess('確認メールを送信しました。メールのリンクをクリックして登録を完了してください。')
        }
      }
      
    } catch (error) {
      console.error('Supabase signup error:', error)
      this.showError('サインアップに失敗しました。再度お試しください。')
    } finally {
      this.setLoading(false)
    }
  }

  async resetPassword(event) {
    event.preventDefault()
    
    const email = this.emailTarget.value
    if (!email) {
      this.showError('パスワードリセット用のメールアドレスを入力してください')
      return
    }
    
    try {
      this.setLoading(true)
      
      const { error } = await this.supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/auth/reset-password`
      })
      
      if (error) {
        this.showError(`パスワードリセットエラー: ${error.message}`)
      } else {
        this.showSuccess('パスワードリセット用のメールを送信しました')
      }
    } catch (error) {
      console.error('Password reset error:', error)
      this.showError('パスワードリセットに失敗しました')
    } finally {
      this.setLoading(false)
    }
  }

  handleSuccessfulLogin(accessToken) {
    // Supabaseトークンを使ってRailsサーバーにログイン
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = this.loginFormTarget.action
    
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content
    const csrfInput = document.createElement('input')
    csrfInput.type = 'hidden'
    csrfInput.name = 'authenticity_token'
    csrfInput.value = csrfToken
    
    const tokenInput = document.createElement('input')
    tokenInput.type = 'hidden'
    tokenInput.name = 'supabase_token'
    tokenInput.value = accessToken
    
    form.appendChild(csrfInput)
    form.appendChild(tokenInput)
    
    document.body.appendChild(form)
    form.submit()
  }

  showError(message) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorMessageTarget.classList.remove('hidden')
      this.errorMessageTarget.classList.add('alert-error')
      this.errorMessageTarget.classList.remove('alert-success')
    }
  }

  showSuccess(message) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorMessageTarget.classList.remove('hidden')
      this.errorMessageTarget.classList.add('alert-success')
      this.errorMessageTarget.classList.remove('alert-error')
    }
  }

  clearError() {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.classList.add('hidden')
    }
  }

  setLoading(isLoading) {
    const buttons = this.element.querySelectorAll('button[type="submit"]')
    buttons.forEach(button => {
      if (isLoading) {
        button.disabled = true
        button.textContent = '処理中...'
      } else {
        button.disabled = false
        // ボタンテキストを元に戻す（データ属性から取得）
        const originalText = button.getAttribute('data-original-text') || 'ログイン'
        button.textContent = originalText
      }
    })
  }
} 
