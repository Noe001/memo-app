const { createClient } = require('@supabase/supabase-js');
const axios = require('axios');

// Supabase設定
const supabaseUrl = 'http://127.0.0.1:54321';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Rails アプリケーションの設定
const railsBaseUrl = 'http://localhost:3000';

async function debugAuth() {
  try {
    console.log('=== 認証デバッグ開始 ===');
    
    // 1. 新しいユーザーを作成
    console.log('\n1. 新しいユーザー作成');
    const testEmail = `debug_${Date.now()}@example.com`;
    const testPassword = 'debugpassword123';
    
    const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
      email: testEmail,
      password: testPassword
    });
    
    if (signUpError) {
      console.error('❌ ユーザー作成エラー:', signUpError.message);
      return;
    }
    
    console.log('✅ ユーザー作成成功:', signUpData.user.email);
    
    // 2. セッション取得
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
      console.error('❌ セッション取得失敗');
      return;
    }
    
    console.log('✅ セッション取得成功');
    console.log('User ID:', session.user.id);
    console.log('Email:', session.user.email);
    console.log('Token (最初の50文字):', session.access_token.substring(0, 50) + '...');
    
    // 3. Supabase APIでユーザー情報を直接取得
    console.log('\n2. Supabase API直接テスト');
    try {
      const userResponse = await axios.get(`${supabaseUrl}/auth/v1/user`, {
        headers: {
          'Authorization': `Bearer ${session.access_token}`,
          'apikey': supabaseAnonKey
        }
      });
      
      console.log('✅ Supabase /auth/v1/user API成功');
      console.log('ユーザー情報:', JSON.stringify(userResponse.data, null, 2));
    } catch (error) {
      console.error('❌ Supabase API エラー:', error.message);
      if (error.response) {
        console.log('ステータス:', error.response.status);
        console.log('レスポンス:', error.response.data);
      }
    }
    
    // 4. プロフィール情報取得
    console.log('\n3. プロフィール情報取得テスト');
    try {
      const profileResponse = await axios.get(`${supabaseUrl}/rest/v1/profiles?id=eq.${session.user.id}&select=*`, {
        headers: {
          'Authorization': `Bearer ${supabaseAnonKey}`,
          'apikey': supabaseAnonKey,
          'Content-Type': 'application/json'
        }
      });
      
      console.log('✅ プロフィール情報取得成功');
      console.log('プロフィール情報:', JSON.stringify(profileResponse.data, null, 2));
    } catch (error) {
      console.error('❌ プロフィール情報取得エラー:', error.message);
      if (error.response) {
        console.log('ステータス:', error.response.status);
        console.log('レスポンス:', error.response.data);
      }
    }
    
    // 5. Rails アプリケーションの認証テスト
    console.log('\n4. Rails アプリケーション認証テスト');
    try {
      const railsResponse = await axios.get(`${railsBaseUrl}/memos`, {
        headers: {
          'Authorization': `Bearer ${session.access_token}`,
          'Accept': 'text/html'
        }
      });
      
      console.log('✅ Rails認証成功');
      console.log('レスポンスステータス:', railsResponse.status);
      
      // ログインページが表示されているかチェック
      const isLoginPage = railsResponse.data.includes('ログイン') && railsResponse.data.includes('メールアドレス');
      if (isLoginPage) {
        console.log('⚠️ ログインページが表示されました - Rails認証が失敗している可能性があります');
      } else {
        console.log('✅ メモページが表示されました');
      }
    } catch (error) {
      console.error('❌ Rails認証エラー:', error.message);
      if (error.response) {
        console.log('ステータス:', error.response.status);
        console.log('レスポンス（最初の200文字）:', error.response.data.substring(0, 200));
      }
    }
    
    // 6. JWTトークンの詳細確認
    console.log('\n5. JWTトークン詳細確認');
    try {
      // JWTトークンをデコード（検証なし）
      const tokenParts = session.access_token.split('.');
      const header = JSON.parse(Buffer.from(tokenParts[0], 'base64').toString());
      const payload = JSON.parse(Buffer.from(tokenParts[1], 'base64').toString());
      
      console.log('JWTヘッダー:', JSON.stringify(header, null, 2));
      console.log('JWTペイロード:', JSON.stringify(payload, null, 2));
      
      // 有効期限チェック
      const exp = new Date(payload.exp * 1000);
      const now = new Date();
      console.log('トークン有効期限:', exp.toISOString());
      console.log('現在時刻:', now.toISOString());
      console.log('トークン有効:', exp > now);
      
    } catch (error) {
      console.error('❌ JWTトークン解析エラー:', error.message);
    }
    
    // 7. ログアウト
    console.log('\n6. ログアウト');
    await supabase.auth.signOut();
    console.log('✅ ログアウト完了');
    
  } catch (error) {
    console.error('❌ デバッグエラー:', error.message);
    console.error(error.stack);
  }
}

// デバッグ実行
debugAuth(); 
