// Supabase API操作サービス
class SupabaseService {
  constructor() {
    this.baseURL = window.ENV?.SUPABASE_URL || 'http://localhost:54321';
    this.apiKey = window.ENV?.SUPABASE_ANON_KEY || 'your-anon-key';
    this.headers = {
      'Content-Type': 'application/json',
      'apikey': this.apiKey,
      'Authorization': `Bearer ${this.apiKey}`
    };
  }
  
  // 認証ヘッダーを取得
  getAuthHeaders() {
    const token = this.getAuthToken();
    return {
      ...this.headers,
      'Authorization': `Bearer ${token || this.apiKey}`
    };
  }
  
  // 認証トークンを取得
  getAuthToken() {
    if (window.authService && window.authService.token) {
      return window.authService.token;
    }
    return null;
  }
  
  // 現在のユーザーIDを取得
  getCurrentUserId() {
    if (window.authService && window.authService.currentUser) {
      return window.authService.currentUser.id;
    }
    return null;
  }
  
  // メモ関連API
  
  // メモ一覧取得
  async getMemos(userId, filters = {}) {
    try {
      const params = new URLSearchParams();
      params.append('select', 'id,title,description,visibility,created_at,updated_at,user_id,tags(id,name)');
      params.append('user_id', `eq.${userId}`);
      params.append('order', 'updated_at.desc');
      
      // 検索フィルター
      if (filters.search) {
        params.append('or', `title.ilike.%${filters.search}%,description.ilike.%${filters.search}%`);
      }
      
      // ページネーション
      if (filters.page && filters.limit) {
        const offset = (filters.page - 1) * filters.limit;
        params.append('offset', offset);
        params.append('limit', filters.limit);
      }
      
      const response = await fetch(`${this.baseURL}/rest/v1/memos?${params}`, {
        method: 'GET',
        headers: this.getAuthHeaders()
      });
      
      if (!response.ok) {
        throw new Error(`Failed to fetch memos: ${response.status}`);
      }
      
      const data = await response.json();
      return { success: true, data };
    } catch (error) {
      console.error('Error fetching memos:', error);
      return { success: false, error: error.message };
    }
  }
  
  // メモ作成
  async createMemo(memo) {
    try {
      const userId = this.getCurrentUserId();
      if (!userId) {
        throw new Error('User not authenticated');
      }
      
      const memoData = {
        ...memo,
        user_id: userId,
        visibility: memo.visibility || 'private_memo'
      };
      
      const response = await fetch(`${this.baseURL}/rest/v1/memos`, {
        method: 'POST',
        headers: this.getAuthHeaders(),
        body: JSON.stringify(memoData)
      });
      
      if (!response.ok) {
        throw new Error(`Failed to create memo: ${response.status}`);
      }
      
      const data = await response.json();
      const createdMemo = data[0];
      
      // タグがある場合は関連付け
      if (memo.tags && memo.tags.length > 0) {
        await this.updateMemoTags(createdMemo.id, memo.tags);
      }
      
      return { success: true, data: createdMemo };
    } catch (error) {
      console.error('Error creating memo:', error);
      return { success: false, error: error.message };
    }
  }
  
  // メモ更新
  async updateMemo(id, updates) {
    try {
      const userId = this.getCurrentUserId();
      if (!userId) {
        throw new Error('User not authenticated');
      }
      
      const { tags, ...memoUpdates } = updates;
      
      const response = await fetch(`${this.baseURL}/rest/v1/memos?id=eq.${id}&user_id=eq.${userId}`, {
        method: 'PATCH',
        headers: this.getAuthHeaders(),
        body: JSON.stringify(memoUpdates)
      });
      
      if (!response.ok) {
        throw new Error(`Failed to update memo: ${response.status}`);
      }
      
      const data = await response.json();
      const updatedMemo = data[0];
      
      // タグを更新
      if (tags) {
        await this.updateMemoTags(id, tags);
      }
      
      return { success: true, data: updatedMemo };
    } catch (error) {
      console.error('Error updating memo:', error);
      return { success: false, error: error.message };
    }
  }
  
  // メモ削除
  async deleteMemo(id) {
    try {
      const userId = this.getCurrentUserId();
      if (!userId) {
        throw new Error('User not authenticated');
      }
      
      const response = await fetch(`${this.baseURL}/rest/v1/memos?id=eq.${id}&user_id=eq.${userId}`, {
        method: 'DELETE',
        headers: this.getAuthHeaders()
      });
      
      if (!response.ok) {
        throw new Error(`Failed to delete memo: ${response.status}`);
      }
      
      return { success: true };
    } catch (error) {
      console.error('Error deleting memo:', error);
      return { success: false, error: error.message };
    }
  }
  
  // メモ検索
  async searchMemos(userId, query, tags = []) {
    try {
      const params = new URLSearchParams();
      params.append('select', 'id,title,description,visibility,created_at,updated_at,user_id,tags(id,name)');
      params.append('user_id', `eq.${userId}`);
      
      // テキスト検索
      if (query) {
        params.append('or', `title.ilike.%${query}%,description.ilike.%${query}%`);
      }
      
      // タグフィルター（複雑なクエリのため、後処理で実装）
      params.append('order', 'updated_at.desc');
      
      const response = await fetch(`${this.baseURL}/rest/v1/memos?${params}`, {
        method: 'GET',
        headers: this.getAuthHeaders()
      });
      
      if (!response.ok) {
        throw new Error(`Failed to search memos: ${response.status}`);
      }
      
      let data = await response.json();
      
      // タグフィルターを適用
      if (tags.length > 0) {
        data = data.filter(memo => {
          if (!memo.tags || memo.tags.length === 0) return false;
          const memoTagNames = memo.tags.map(tag => tag.name);
          return tags.every(tag => memoTagNames.includes(tag));
        });
      }
      
      return { success: true, data };
    } catch (error) {
      console.error('Error searching memos:', error);
      return { success: false, error: error.message };
    }
  }
  
  // タグ関連API
  
  // タグ一覧取得
  async getTags(userId) {
    try {
      const params = new URLSearchParams();
      params.append('select', 'id,name,created_at');
      params.append('user_id', `eq.${userId}`);
      params.append('order', 'name.asc');
      
      const response = await fetch(`${this.baseURL}/rest/v1/tags?${params}`, {
        method: 'GET',
        headers: this.getAuthHeaders()
      });
      
      if (!response.ok) {
        throw new Error(`Failed to fetch tags: ${response.status}`);
      }
      
      const data = await response.json();
      return { success: true, data };
    } catch (error) {
      console.error('Error fetching tags:', error);
      return { success: false, error: error.message };
    }
  }
  
  // タグ作成
  async createTag(tagName) {
    try {
      const userId = this.getCurrentUserId();
      if (!userId) {
        throw new Error('User not authenticated');
      }
      
      const tagData = {
        name: tagName,
        user_id: userId
      };
      
      const response = await fetch(`${this.baseURL}/rest/v1/tags`, {
        method: 'POST',
        headers: this.getAuthHeaders(),
        body: JSON.stringify(tagData)
      });
      
      if (!response.ok) {
        throw new Error(`Failed to create tag: ${response.status}`);
      }
      
      const data = await response.json();
      return { success: true, data: data[0] };
    } catch (error) {
      console.error('Error creating tag:', error);
      return { success: false, error: error.message };
    }
  }
  
  // メモタグ関連付け更新
  async updateMemoTags(memoId, tagNames) {
    try {
      const userId = this.getCurrentUserId();
      if (!userId) {
        throw new Error('User not authenticated');
      }
      
      // 既存のメモタグ関連付けを削除
      await fetch(`${this.baseURL}/rest/v1/memo_tags?memo_id=eq.${memoId}`, {
        method: 'DELETE',
        headers: this.getAuthHeaders()
      });
      
      // 新しいタグ関連付けを作成
      for (const tagName of tagNames) {
        if (!tagName.trim()) continue;
        
        // タグが存在するかチェック
        let tag = await this.findOrCreateTag(tagName.trim());
        
        // メモタグ関連付けを作成
        await fetch(`${this.baseURL}/rest/v1/memo_tags`, {
          method: 'POST',
          headers: this.getAuthHeaders(),
          body: JSON.stringify({
            memo_id: memoId,
            tag_id: tag.id
          })
        });
      }
      
      return { success: true };
    } catch (error) {
      console.error('Error updating memo tags:', error);
      return { success: false, error: error.message };
    }
  }
  
  // タグを検索または作成
  async findOrCreateTag(tagName) {
    try {
      const userId = this.getCurrentUserId();
      
      // 既存のタグを検索
      const params = new URLSearchParams();
      params.append('select', 'id,name');
      params.append('user_id', `eq.${userId}`);
      params.append('name', `eq.${tagName}`);
      
      const response = await fetch(`${this.baseURL}/rest/v1/tags?${params}`, {
        method: 'GET',
        headers: this.getAuthHeaders()
      });
      
      if (response.ok) {
        const data = await response.json();
        if (data.length > 0) {
          return data[0];
        }
      }
      
      // タグが存在しない場合は作成
      const createResult = await this.createTag(tagName);
      if (createResult.success) {
        return createResult.data;
      }
      
      throw new Error('Failed to find or create tag');
    } catch (error) {
      console.error('Error finding or creating tag:', error);
      throw error;
    }
  }
  
  // 公開メモ取得
  async getPublicMemos(filters = {}) {
    try {
      const params = new URLSearchParams();
      params.append('select', 'id,title,description,created_at,updated_at,user_id,tags(id,name)');
      params.append('visibility', 'eq.public_memo');
      params.append('order', 'updated_at.desc');
      
      if (filters.search) {
        params.append('or', `title.ilike.%${filters.search}%,description.ilike.%${filters.search}%`);
      }
      
      if (filters.page && filters.limit) {
        const offset = (filters.page - 1) * filters.limit;
        params.append('offset', offset);
        params.append('limit', filters.limit);
      }
      
      const response = await fetch(`${this.baseURL}/rest/v1/memos?${params}`, {
        method: 'GET',
        headers: this.getAuthHeaders()
      });
      
      if (!response.ok) {
        throw new Error(`Failed to fetch public memos: ${response.status}`);
      }
      
      const data = await response.json();
      return { success: true, data };
    } catch (error) {
      console.error('Error fetching public memos:', error);
      return { success: false, error: error.message };
    }
  }
  
  // リアルタイム機能
  
  // メモ変更のリアルタイム監視
  subscribeToMemoChanges(userId, callback) {
    if (!window.WebSocket) {
      console.warn('WebSocket not supported');
      return null;
    }
    
    const wsUrl = `${this.baseURL.replace('http', 'ws')}/realtime/v1/websocket`;
    const socket = new WebSocket(wsUrl);
    
    socket.onopen = () => {
      console.log('Supabase realtime connected');
      
      // メモテーブルの変更を監視
      socket.send(JSON.stringify({
        topic: 'memos',
        event: 'phx_join',
        payload: {
          config: {
            postgres_changes: [{
              event: '*',
              schema: 'public',
              table: 'memos',
              filter: `user_id=eq.${userId}`
            }]
          }
        }
      }));
    };
    
    socket.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.event === 'postgres_changes') {
        callback(data.payload);
      }
    };
    
    socket.onerror = (error) => {
      console.error('Supabase realtime error:', error);
    };
    
    return socket;
  }
  
  // リアルタイム接続を終了
  unsubscribeFromMemoChanges(socket) {
    if (socket) {
      socket.close();
    }
  }
}

// グローバルにインスタンスを作成
window.supabaseService = new SupabaseService();

// エクスポート
export default window.supabaseService; 
