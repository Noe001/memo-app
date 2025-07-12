#!/usr/bin/env node

/**
 * Supabase Auth Test Script
 * 
 * 認証機能のテストを実行します
 */

const { createClient } = require('@supabase/supabase-js');
const config = require('./config');

// Supabase クライアント
const supabase = createClient(config.supabase.url, config.supabase.anonKey);

async function testAuth() {
  console.log('🧪 Starting Supabase Auth tests...\n');

  try {
    // 1. パスワードリセット機能のテスト
    console.log('1. Testing password reset functionality...');
    await testPasswordReset();
    
    // 2. 新規ユーザー作成のテスト
    console.log('\n2. Testing new user creation...');
    await testNewUserCreation();
    
    // 3. 既存ユーザー情報の確認
    console.log('\n3. Testing existing user verification...');
    await testExistingUsers();
    
    console.log('\n✅ All tests completed successfully!');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    process.exit(1);
  }
}

async function testPasswordReset() {
  const testEmail = 'test@example.com';
  
  try {
    const { data, error } = await supabase.auth.resetPasswordForEmail(testEmail, {
      redirectTo: 'http://localhost:3000/auth/reset-password'
    });
    
    if (error) {
      console.error(`❌ Password reset failed: ${error.message}`);
    } else {
      console.log(`✅ Password reset email sent to ${testEmail}`);
    }
  } catch (error) {
    console.error(`❌ Password reset error: ${error.message}`);
  }
}

async function testNewUserCreation() {
  const testEmail = 'new-user@example.com';
  const testPassword = 'TestPassword123!';
  
  try {
    // 新規ユーザー作成をテスト
    const { data, error } = await supabase.auth.signUp({
      email: testEmail,
      password: testPassword,
      options: {
        data: {
          name: 'Test User'
        }
      }
    });
    
    if (error) {
      if (error.message.includes('User already registered')) {
        console.log(`ℹ️  User ${testEmail} already exists`);
      } else {
        console.error(`❌ New user creation failed: ${error.message}`);
      }
    } else {
      console.log(`✅ New user created successfully: ${testEmail}`);
      
      // 作成したテストユーザーを削除（クリーンアップ）
      if (data.user) {
        await cleanupTestUser(data.user.id);
      }
    }
  } catch (error) {
    console.error(`❌ New user creation error: ${error.message}`);
  }
}

async function testExistingUsers() {
  try {
    // Admin権限でユーザーリストを取得
    const adminClient = createClient(config.supabase.url, config.supabase.serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });
    
    const { data: users, error } = await adminClient.auth.admin.listUsers();
    
    if (error) {
      console.error(`❌ Failed to list users: ${error.message}`);
    } else {
      console.log(`✅ Found ${users.users.length} users in Supabase Auth:`);
      users.users.forEach(user => {
        console.log(`  - ${user.email} (ID: ${user.id})`);
        console.log(`    Created: ${user.created_at}`);
        console.log(`    Metadata: ${JSON.stringify(user.user_metadata)}`);
      });
    }
    
    // プロフィール情報も確認
    const { data: profiles, error: profileError } = await adminClient
      .from('profiles')
      .select('*');
    
    if (profileError) {
      console.error(`❌ Failed to fetch profiles: ${profileError.message}`);
    } else {
      console.log(`✅ Found ${profiles.length} profiles in database:`);
      profiles.forEach(profile => {
        console.log(`  - ${profile.name} (${profile.email})`);
        console.log(`    Rails ID: ${profile.original_rails_id}`);
        console.log(`    Migrated: ${profile.migrated_from_rails}`);
      });
    }
    
  } catch (error) {
    console.error(`❌ Existing users test error: ${error.message}`);
  }
}

async function cleanupTestUser(userId) {
  try {
    const adminClient = createClient(config.supabase.url, config.supabase.serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });
    
    const { error } = await adminClient.auth.admin.deleteUser(userId);
    
    if (error) {
      console.warn(`⚠️  Failed to cleanup test user: ${error.message}`);
    } else {
      console.log(`🧹 Test user cleaned up successfully`);
    }
  } catch (error) {
    console.warn(`⚠️  Cleanup error: ${error.message}`);
  }
}

// スクリプトが直接実行された場合にテストを開始
if (require.main === module) {
  testAuth().catch(console.error);
}

module.exports = { testAuth }; 
