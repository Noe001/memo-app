const { createClient } = require('@supabase/supabase-js');
const axios = require('axios');

// Supabase設定
const supabaseUrl = 'http://127.0.0.1:54321';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Rails アプリケーションの設定
const railsBaseUrl = 'http://localhost:3000';

async function testMemoAuthFlow() {
  try {
    console.log('=== メモ機能認証テスト開始 ===');
    
    // 1. 新しいユーザーの作成
    console.log('\n1. 新しいユーザー作成テスト');
    const testEmail = `test_${Date.now()}@example.com`;
    const testPassword = 'testpassword123';
    
    const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
      email: testEmail,
      password: testPassword
    });
    
    if (signUpError) {
      console.error('❌ ユーザー作成エラー:', signUpError.message);
      
      // 既存ユーザーでログインを試行
      console.log('\n既存ユーザーでログインテスト');
      const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
        email: 'test@example.com',
        password: 'testpassword123'
      });
      
      if (signInError) {
        console.error('❌ 既存ユーザーログインエラー:', signInError.message);
        return;
      }
      
      console.log('✅ 既存ユーザーログイン成功:', signInData.user.email);
    } else {
      console.log('✅ 新規ユーザー作成成功:', signUpData.user.email);
    }
    
    // 2. JWTトークンの取得
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
      console.error('❌ セッション取得エラー');
      return;
    }
    
    console.log('✅ JWTトークン取得成功');
    
    // 3. Rails メモ一覧ページへのアクセステスト
    console.log('\n2. Rails メモ一覧ページアクセステスト');
    try {
      const response = await axios.get(`${railsBaseUrl}/memos`, {
        headers: {
          'Authorization': `Bearer ${session.access_token}`,
          'Accept': 'text/html'
        }
      });
      
      if (response.status === 200) {
        console.log('✅ メモ一覧ページアクセス成功');
        
        // レスポンスにメモ関連の要素が含まれているかチェック
        const hasMemosContainer = response.data.includes('memos-container') || 
                                 response.data.includes('memo-list') ||
                                 response.data.includes('class="memo"') ||
                                 response.data.includes('メモ一覧');
        
        if (hasMemosContainer) {
          console.log('✅ メモ一覧ページの構造が正常');
        } else {
          console.log('⚠️ メモ一覧ページの構造を確認してください');
          console.log('レスポンスの最初の500文字:', response.data.substring(0, 500));
        }
      } else {
        console.log('❌ メモ一覧ページアクセス失敗:', response.status);
      }
    } catch (error) {
      console.error('❌ メモ一覧ページアクセスエラー:', error.message);
      if (error.response) {
        console.log('レスポンスステータス:', error.response.status);
        console.log('レスポンスヘッダー:', error.response.headers);
      }
    }
    
    // 4. メモ作成テスト
    console.log('\n3. メモ作成テスト');
    try {
      const createResponse = await axios.post(`${railsBaseUrl}/memos`, {
        memo: {
          title: 'テストメモ',
          content: 'これはSupabase認証でのテストメモです。'
        }
      }, {
        headers: {
          'Authorization': `Bearer ${session.access_token}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }
      });
      
      if (createResponse.status === 201) {
        console.log('✅ メモ作成成功');
      } else {
        console.log('❌ メモ作成失敗:', createResponse.status);
      }
    } catch (error) {
      console.error('❌ メモ作成エラー:', error.message);
      if (error.response) {
        console.log('レスポンスステータス:', error.response.status);
        console.log('レスポンスヘッダー:', error.response.headers);
      }
    }
    
    // 5. ログアウト
    console.log('\n4. ログアウトテスト');
    const { error: signOutError } = await supabase.auth.signOut();
    if (signOutError) {
      console.error('❌ ログアウトエラー:', signOutError.message);
    } else {
      console.log('✅ ログアウト成功');
    }
    
    console.log('\n=== テスト完了 ===');
    
  } catch (error) {
    console.error('❌ テスト実行エラー:', error.message);
    console.error(error.stack);
  }
}

// レガシー認証テスト
async function testLegacyAuthFlow() {
  try {
    console.log('\n=== レガシー認証テスト開始 ===');
    
    // CSRF トークンの取得
    const loginPageResponse = await axios.get(`${railsBaseUrl}/login`);
    const csrfToken = loginPageResponse.data.match(/name="authenticity_token" value="([^"]+)"/)?.[1];
    
    if (!csrfToken) {
      console.error('❌ CSRFトークン取得失敗');
      return;
    }
    
    console.log('✅ CSRFトークン取得成功');
    
    // レガシー認証でのログイン
    const params = new URLSearchParams();
    params.append('email', 'legacy_test@example.com');
    params.append('password', 'legacypassword123');
    params.append('authenticity_token', csrfToken);
    
    const loginResponse = await axios.post(`${railsBaseUrl}/login`, params, {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      maxRedirects: 0,
      validateStatus: function (status) {
        return status >= 200 && status < 400;
      }
    });
    
    if (loginResponse.status === 302) {
      console.log('✅ レガシー認証成功（リダイレクト）');
      
      // ログイン後にメモページにアクセステスト
      const cookies = loginResponse.headers['set-cookie'];
      if (cookies) {
        console.log('\n✅ セッションCookie取得成功');
        
        // セッションCookieを使ってメモページにアクセス
        try {
          const memosResponse = await axios.get(`${railsBaseUrl}/memos`, {
            headers: {
              'Cookie': cookies.join('; ')
            }
          });
          
          if (memosResponse.status === 200) {
            console.log('✅ レガシー認証でメモページアクセス成功');
          } else {
            console.log('❌ レガシー認証でメモページアクセス失敗:', memosResponse.status);
          }
        } catch (error) {
          console.error('❌ レガシー認証メモページアクセスエラー:', error.message);
        }
      }
    } else {
      console.log('❌ レガシー認証失敗:', loginResponse.status);
    }
    
  } catch (error) {
    console.error('❌ レガシー認証テストエラー:', error.message);
    if (error.response) {
      console.log('レスポンスステータス:', error.response.status);
      console.log('レスポンスヘッダー:', error.response.headers);
      if (error.response.status === 422) {
        console.log('レスポンス内容（最初の200文字）:', error.response.data.substring(0, 200));
      }
    }
  }
}

// テスト実行
(async () => {
  await testMemoAuthFlow();
  await testLegacyAuthFlow();
})(); 
