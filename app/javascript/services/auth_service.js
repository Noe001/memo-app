// Supabase認証サービス
class AuthService {
  constructor() {
    this.baseURL = '/auth';
    this.currentUser = null;
    this.token = null;
    this.refreshTimer = null;
    
    // 初期化時にトークンの確認
    this.checkAuthStatus();
  }
  
  // 現在の認証状態を確認
  async checkAuthStatus() {
    try {
      const response = await fetch('/auth/current_user_info', {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        },
        credentials: 'include'
      });
      
      if (response.ok) {
        const data = await response.json();
        this.currentUser = data.user;
        this.startTokenRefresh();
        return true;
      } else {
        this.currentUser = null;
        this.clearTokenRefresh();
        return false;
      }
    } catch (error) {
      console.error('Auth status check failed:', error);
      this.currentUser = null;
      this.clearTokenRefresh();
      return false;
    }
  }
  
  // ログイン
  async login(email, password) {
    try {
      const response = await fetch('/auth/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        },
        body: JSON.stringify({
          email: email,
          password: password
        }),
        credentials: 'include'
      });
      
      const data = await response.json();
      
      if (response.ok && data.success) {
        this.currentUser = data.user;
        this.token = data.access_token;
        this.startTokenRefresh();
        
        // ログイン成功イベントを発火
        window.dispatchEvent(new CustomEvent('auth:login', {
          detail: { user: this.currentUser }
        }));
        
        return { success: true, user: this.currentUser };
      } else {
        return { success: false, error: data.error || 'ログインに失敗しました' };
      }
    } catch (error) {
      console.error('Login failed:', error);
      return { success: false, error: 'ログイン中にエラーが発生しました' };
    }
  }
  
  // サインアップ
  async signup(email, password, name) {
    try {
      const response = await fetch('/auth/signup', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        },
        body: JSON.stringify({
          email: email,
          password: password,
          name: name
        }),
        credentials: 'include'
      });
      
      const data = await response.json();
      
      if (response.ok && data.success) {
        this.currentUser = data.user;
        this.token = data.access_token;
        this.startTokenRefresh();
        
        // サインアップ成功イベントを発火
        window.dispatchEvent(new CustomEvent('auth:signup', {
          detail: { user: this.currentUser }
        }));
        
        return { success: true, user: this.currentUser };
      } else {
        return { success: false, error: data.error || 'アカウント作成に失敗しました' };
      }
    } catch (error) {
      console.error('Signup failed:', error);
      return { success: false, error: 'アカウント作成中にエラーが発生しました' };
    }
  }
  
  // ログアウト
  async logout() {
    try {
      const response = await fetch('/auth/logout', {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        },
        credentials: 'include'
      });
      
      const data = await response.json();
      
      if (response.ok && data.success) {
        this.currentUser = null;
        this.token = null;
        this.clearTokenRefresh();
        
        // ログアウト成功イベントを発火
        window.dispatchEvent(new CustomEvent('auth:logout'));
        
        return { success: true };
      } else {
        return { success: false, error: data.error || 'ログアウトに失敗しました' };
      }
    } catch (error) {
      console.error('Logout failed:', error);
      return { success: false, error: 'ログアウト中にエラーが発生しました' };
    }
  }
  
  // トークン更新
  async refreshToken() {
    try {
      const response = await fetch('/auth/refresh_token', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        },
        credentials: 'include'
      });
      
      const data = await response.json();
      
      if (response.ok && data.success) {
        this.token = data.access_token;
        this.currentUser = data.user;
        return { success: true };
      } else {
        // リフレッシュに失敗した場合は認証状態をクリア
        this.currentUser = null;
        this.token = null;
        this.clearTokenRefresh();
        
        // 認証エラーイベントを発火
        window.dispatchEvent(new CustomEvent('auth:error', {
          detail: { error: 'セッションが無効です' }
        }));
        
        return { success: false, error: data.error || 'トークンの更新に失敗しました' };
      }
    } catch (error) {
      console.error('Token refresh failed:', error);
      this.currentUser = null;
      this.token = null;
      this.clearTokenRefresh();
      
      window.dispatchEvent(new CustomEvent('auth:error', {
        detail: { error: 'セッションが無効です' }
      }));
      
      return { success: false, error: 'トークンの更新中にエラーが発生しました' };
    }
  }
  
  // 定期的なトークン更新を開始
  startTokenRefresh() {
    this.clearTokenRefresh();
    
    // 50分ごとにトークンを更新（トークンの有効期限は1時間）
    this.refreshTimer = setInterval(() => {
      this.refreshToken();
    }, 50 * 60 * 1000);
  }
  
  // トークン更新タイマーをクリア
  clearTokenRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = null;
    }
  }
  
  // 現在のユーザーを取得
  getCurrentUser() {
    return this.currentUser;
  }
  
  // 認証状態を確認
  isAuthenticated() {
    return this.currentUser !== null;
  }
  
  // 認証が必要なAPIリクエストを送信
  async authenticatedRequest(url, options = {}) {
    const defaultOptions = {
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      },
      credentials: 'include'
    };
    
    const mergedOptions = {
      ...defaultOptions,
      ...options,
      headers: {
        ...defaultOptions.headers,
        ...options.headers
      }
    };
    
    try {
      const response = await fetch(url, mergedOptions);
      
      // 認証エラーの場合は自動的にログアウト
      if (response.status === 401) {
        this.currentUser = null;
        this.token = null;
        this.clearTokenRefresh();
        
        window.dispatchEvent(new CustomEvent('auth:error', {
          detail: { error: 'セッションが無効です' }
        }));
        
        // ログインページにリダイレクト
        window.location.href = '/login';
        return null;
      }
      
      return response;
    } catch (error) {
      console.error('Authenticated request failed:', error);
      throw error;
    }
  }
}

// グローバルにインスタンスを作成
window.authService = new AuthService();

// エクスポート
export default window.authService; 
