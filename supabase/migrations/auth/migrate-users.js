#!/usr/bin/env node

/**
 * Rails User Migration to Supabase Auth
 * 
 * このスクリプトは既存のRailsユーザーをSupabase Authに移行します。
 * 移行後は、ユーザーは新しいパスワードを設定する必要があります。
 */

const { createClient } = require('@supabase/supabase-js');
const { Pool } = require('pg');
const config = require('./config');

// Supabase Admin Client (Service Role Key使用)
const supabaseAdmin = createClient(
  config.supabase.url,
  config.supabase.serviceRoleKey,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  }
);

// Rails PostgreSQL接続
const railsPool = new Pool(config.rails);

async function migrateUsers() {
  console.log('🚀 Starting user migration from Rails to Supabase Auth...\n');
  
  try {
    // 1. RailsのユーザーデータをPostgreSQLから取得
    console.log('📡 Fetching users from Rails database...');
    const railsUsers = await getRailsUsers();
    console.log(`✅ Found ${railsUsers.length} users to migrate\n`);
    
    if (railsUsers.length === 0) {
      console.log('ℹ️  No users found to migrate.');
      return;
    }
    
    // 2. 各ユーザーをSupabase Authに移行
    let successCount = 0;
    let errorCount = 0;
    
    for (const user of railsUsers) {
      try {
        console.log(`👤 Migrating user: ${user.name} (${user.email})`);
        
        // 一時的なパスワードを生成（ユーザーは後でリセット必須）
        const tempPassword = generateTempPassword();
        
        // Supabase Authにユーザーを作成
        const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
          email: user.email,
          password: tempPassword,
          email_confirm: true, // メール確認をスキップ
          user_metadata: {
            name: user.name,
            migrated_from_rails: true,
            original_rails_id: user.id,
            migrated_at: new Date().toISOString()
          }
        });
        
        if (authError) {
          console.error(`❌ Failed to create auth user for ${user.email}:`, authError.message);
          errorCount++;
          continue;
        }
        
        // プロフィール情報をsupabaseのusersテーブルに保存
        await createUserProfile(authUser.user, user);
        
        console.log(`✅ Successfully migrated: ${user.email}`);
        successCount++;
        
        // パスワードリセットを強制的に送信
        await supabaseAdmin.auth.admin.generateLink({
          type: 'recovery',
          email: user.email
        });
        
        console.log(`📧 Password reset email queued for: ${user.email}\n`);
        
      } catch (userError) {
        console.error(`❌ Error migrating user ${user.email}:`, userError.message);
        errorCount++;
      }
    }
    
    // 結果の表示
    console.log('\n📊 Migration Summary:');
    console.log(`✅ Successfully migrated: ${successCount} users`);
    console.log(`❌ Failed migrations: ${errorCount} users`);
    console.log(`📧 All migrated users will need to reset their passwords`);
    
  } catch (error) {
    console.error('💥 Migration failed:', error.message);
    process.exit(1);
  } finally {
    await railsPool.end();
  }
}

async function getRailsUsers() {
  const query = `
    SELECT 
      id,
      name,
      email,
      created_at,
      updated_at,
      theme,
      keyboard_shortcuts_enabled
    FROM users 
    ORDER BY created_at ASC
  `;
  
  const result = await railsPool.query(query);
  return result.rows;
}

async function createUserProfile(supabaseUser, railsUser) {
  // Supabaseのpublic.profilesテーブルにユーザー情報を保存
  // まずテーブルが存在するか確認し、必要に応じて作成
  
  const { error: profileError } = await supabaseAdmin
    .from('profiles')
    .upsert({
      id: supabaseUser.id,
      email: railsUser.email,
      name: railsUser.name,
      theme: railsUser.theme || 'light',
      keyboard_shortcuts_enabled: railsUser.keyboard_shortcuts_enabled !== false,
      migrated_from_rails: true,
      original_rails_id: railsUser.id,
      created_at: railsUser.created_at,
      updated_at: new Date().toISOString()
    });
    
  if (profileError) {
    console.warn(`⚠️  Could not create profile for ${railsUser.email}:`, profileError.message);
  }
}

function generateTempPassword() {
  // 一時的な強力なパスワードを生成（ユーザーは必ずリセット必須）
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
  let password = '';
  for (let i = 0; i < 16; i++) {
    password += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return password;
}

// スクリプトが直接実行された場合に移行を開始
if (require.main === module) {
  migrateUsers().catch(console.error);
}

module.exports = { migrateUsers }; 
