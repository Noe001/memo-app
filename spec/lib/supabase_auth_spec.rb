require 'rails_helper'

RSpec.describe SupabaseAuth do
  let(:valid_refresh_token) { "valid_refresh_token_123" }
  let(:invalid_refresh_token) { "invalid_refresh_token_456" }
  let(:valid_token) { 'valid.jwt.token' }
  let(:expired_token) { 'expired.jwt.token' }
  let(:invalid_token) { 'invalid.jwt.token' }
  let(:user_email) { 'test@example.com' }
  let(:user_id) { 'user-id-123' }
  let(:user_name) { 'Test User' }
  let(:user_password) { 'password123' }
  let(:valid_refresh_token) { 'valid_refresh_token' }
  let(:invalid_refresh_token) { 'invalid_refresh_token' }
  let(:new_access_token) { 'new_access_token' }
  let(:new_refresh_token) { 'new_refresh_token' }
  let(:reset_link) { 'https://example.com/reset-password' }

  before do
    # JWTデコードモック
    allow(JWT).to receive(:decode).and_call_original
    allow(JWT).to receive(:decode).with(valid_token, nil, false).and_return([{ 'sub' => user_id, 'email' => user_email, 'exp' => Time.now.to_i + 3600 }])
    allow(JWT).to receive(:decode).with(expired_token, nil, false).and_return([{ 'exp' => Time.now.to_i - 3600 }])
    allow(JWT).to receive(:decode).with(invalid_token, nil, false).and_raise(JWT::DecodeError)

    # デフォルトのSupabase APIモック
    stub_request(:any, /supabase/).to_return(status: 404)
    
    # パスワードリセット用のモック
    stub_request(:post, "#{SupabaseAuth.supabase_url}/auth/v1/recover")
      .with(body: { email: user_email, redirect_to: "#{Rails.application.config.frontend_url}/reset-password" })
      .to_return(status: 200, body: {}.to_json)
  
    # リフレッシュトークン用のモック
    stub_request(:post, "#{SupabaseAuth.supabase_url}/auth/v1/token")
      .with(body: { grant_type: "refresh_token", refresh_token: valid_refresh_token })
      .to_return(status: 200, body: { access_token: "new_access_token", refresh_token: "new_refresh_token" }.to_json)
  
    stub_request(:post, "#{SupabaseAuth.supabase_url}/auth/v1/token")
      .with(body: { grant_type: "refresh_token", refresh_token: invalid_refresh_token })
      .to_return(status: 401, body: { error: "Invalid refresh token" }.to_json)
  end
  
  describe '#generate_password_reset_link' do

  describe '#refresh_token' do
    context '有効なリフレッシュトークンの場合' do
      it '新しいアクセストークンとリフレッシュトークンを返す' do
        result = described_class.refresh_token(valid_refresh_token)
        expect(result[:access_token]).to eq("new_access_token")
        expect(result[:refresh_token]).to eq("new_refresh_token")
      end
    end

    context '無効なリフレッシュトークンの場合' do
      it 'エラーを発生させる' do
        expect {
          described_class.refresh_token(invalid_refresh_token)
        }.to raise_error(SupabaseAuth::AuthenticationError)
      end
    end

    context 'ネットワークエラーの場合' do
      before do
        stub_request(:post, "#{SupabaseAuth.supabase_url}/auth/v1/token")
          .to_timeout
      end

      it 'ネットワークエラーを発生させる' do
        expect {
          described_class.refresh_token(valid_refresh_token)
        }.to raise_error(SupabaseAuth::NetworkError)
      end
    end
  end

  describe '#sign_out' do
    let(:valid_access_token) { "valid_access_token_123" }
    let(:invalid_access_token) { "invalid_access_token_456" }

    before do
      # ログアウト用のモック
      stub_request(:post, "#{SupabaseAuth.supabase_url}/auth/v1/logout")
        .with(headers: { "Authorization" => "Bearer #{valid_access_token}" })
        .to_return(status: 200, body: {}.to_json)

      stub_request(:post, "#{SupabaseAuth.supabase_url}/auth/v1/logout")
        .with(headers: { "Authorization" => "Bearer #{invalid_access_token}" })
        .to_return(status: 401, body: { error: "Invalid access token" }.to_json)
    end

    context '有効なアクセストークンの場合' do
      it '正常にログアウト処理が完了する' do
        expect {
          described_class.sign_out(valid_access_token)
        }.not_to raise_error
      end
    end

    context '無効なアクセストークンの場合' do
      it 'エラーを発生させる' do
        expect {
          described_class.sign_out(invalid_access_token)
        }.to raise_error(SupabaseAuth::AuthenticationError)
      end
    end

    context 'ネットワークエラーの場合' do
      before do
        stub_request(:post, "#{SupabaseAuth.supabase_url}/auth/v1/logout")
          .to_timeout
      end

      it 'ネットワークエラーを発生させる' do
        expect {
          described_class.sign_out(valid_access_token)
        }.to raise_error(SupabaseAuth::NetworkError)
      end
    end
  end

  describe '.supabase_url' do
    before do
      # 環境変数をリセット
      ENV['SUPABASE_URL'] = nil
      SupabaseAuth.instance_variable_set(:@supabase_url, nil)
    end

    context '環境変数が設定されていない場合' do
      it 'デフォルトURLを返す' do
        expect(SupabaseAuth.supabase_url).to eq('https://api.supabase.io')
      end
    end

    context '環境変数が設定されている場合' do
      let(:custom_url) { 'https://custom.supabase.example.com' }

      before do
        ENV['SUPABASE_URL'] = custom_url
      end

      it '環境変数のURLを返す' do
        expect(SupabaseAuth.supabase_url).to eq(custom_url)
      end
    end

    context '無効なURL形式の場合' do
      before do
        ENV['SUPABASE_URL'] = 'invalid-url'
      end

      it 'ConfigurationErrorを発生させる' do
        expect {
          SupabaseAuth.supabase_url
        }.to raise_error(SupabaseAuth::ConfigurationError)
      end
    end
  end
    context '有効なメールアドレスの場合' do
      it 'パスワードリセットリンクを正常に生成する' do
        expect {
          SupabaseAuth.generate_password_reset_link(user_email)
        }.not_to raise_error
      end
    end
  
    context '無効なメールアドレスの場合' do
      it 'ArgumentErrorを発生させる' do
        expect {
          SupabaseAuth.generate_password_reset_link('invalid_email')
        }.to raise_error(ArgumentError)
      end
    end
  
    context 'ネットワークエラーが発生した場合' do
      before do
        stub_request(:post, "#{SupabaseAuth.supabase_url}/auth/v1/recover")
          .to_return(status: 500)
      end
  
      it 'SupabaseAuthErrorを発生させる' do
        expect {
          SupabaseAuth.generate_password_reset_link(user_email)
        }.to raise_error(SupabaseAuth::SupabaseAuthError)
      end
    end
  end

  describe '.find_available_supabase_host' do
    it '利用可能なホストを返す' do
      stub_request(:get, "http://supabase_kong_notetree:8000/health")
        .to_return(status: 200)
      
      expect(described_class.find_available_supabase_host).to eq('supabase_kong_notetree')
    end

    it 'ホストが見つからない場合デフォルト値を返す' do
      expect(described_class.find_available_supabase_host).to eq('host.docker.internal')
    end
  end

  describe '.verify_token' do
    context '有効なトークンの場合' do
      before do
        stub_request(:get, "http://supabase_kong_notetree:8000/auth/v1/user")
          .with(headers: { 'Authorization' => "Bearer #{valid_token}" })
          .to_return(status: 200, body: { id: user_id, email: user_email }.to_json)

        stub_request(:get, "http://supabase_kong_notetree:8000/rest/v1/profiles?id=eq.#{user_id}&select=*")
          .to_return(status: 200, body: [{ name: user_name }].to_json)
      end

      it 'ユーザー情報を返す' do
        result = described_class.verify_token(valid_token)
        expect(result[:id]).to eq(user_id)
        expect(result[:email]).to eq(user_email)
        expect(result[:name]).to eq(user_name)
      end
    end

    context '無効なトークンの場合' do
      it 'nilを返す' do
        expect(described_class.verify_token(invalid_token)).to be_nil
      end
    end

    context '期限切れトークンの場合' do
      it 'nilを返す' do
        expect(described_class.verify_token(expired_token)).to be_nil
      end
    end
  end

  describe '.sign_in' do
    let(:success_response) do
      {
        access_token: valid_token,
        refresh_token: 'refresh.token',
        user: { id: user_id, email: user_email }
      }
    end

    let(:error_response) do
      { error: 'invalid_grant' }
    end

    context '有効な認証情報の場合' do
      before do
        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=password")
          .with(
            body: { email: user_email, password: user_password },
            headers: { 'Content-Type' => 'application/json' }
          )
          .to_return(status: 200, body: success_response.to_json)

        stub_request(:get, "http://supabase_kong_notetree:8000/rest/v1/profiles?id=eq.#{user_id}&select=*")
          .to_return(status: 200, body: [{ name: user_name }].to_json)
      end

      it '認証に成功しユーザー情報を返す' do
        result = described_class.sign_in(user_email, user_password)
        
        expect(result).to include(
          success: true,
          user: hash_including(
            email: user_email,
            name: user_name
          )
        )
      end
    end

    context '無効な認証情報の場合' do
      before do
        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=password")
          .with(
            body: { email: user_email, password: 'wrong_password' },
            headers: { 'Content-Type' => 'application/json' }
          )
          .to_return(status: 400, body: error_response.to_json)
      end

      it 'エラーメッセージを返す' do
        result = described_class.sign_in(user_email, 'wrong_password')
        
        expect(result).to include(
          success: false,
          error: 'メールアドレスまたはパスワードが正しくありません'
        )
      end
    end

    context 'ネットワークエラーの場合' do
      before do
        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=password")
          .to_timeout
      end

      it 'nilを返す' do
        expect(described_class.sign_in(user_email, user_password)).to be_nil
      end
    end
  end

  describe '.sign_up' do
    context '有効な登録情報の場合' do
      before do
        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/signup")
          .to_return(status: 200, body: {
            access_token: valid_token,
            refresh_token: 'refresh.token',
            user: { id: user_id, email: user_email }
          }.to_json)

        stub_request(:post, "http://supabase_kong_notetree:8000/rest/v1/profiles")
          .to_return(status: 201)
      end

      it '登録に成功する' do
        result = described_class.sign_up(user_email, user_password, user_name)
        expect(result[:success]).to be true
        expect(result[:user][:email]).to eq(user_email)
      end
    
      describe '.refresh_token' do
        let(:valid_refresh_token) { 'valid_refresh_token' }
        let(:new_access_token) { 'new_access_token' }
        let(:new_refresh_token) { 'new_refresh_token' }
    
        context '有効なリフレッシュトークンの場合' do
          before do
            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
              .with(body: { refresh_token: valid_refresh_token })
              .to_return(
                status: 200,
                body: {
                  access_token: new_access_token,
                  refresh_token: new_refresh_token
                }.to_json
              )
          end
    
          it '新しいアクセストークンとリフレッシュトークンを返す' do
            result = described_class.refresh_token(valid_refresh_token)
            expect(result[:access_token]).to eq(new_access_token)
            expect(result[:refresh_token]).to eq(new_refresh_token)
          end
        
          describe '.generate_password_reset_link' do
            let(:valid_email) { 'user@example.com' }
            let(:reset_link) { 'https://example.com/reset-password' }
        
            context '有効なメールアドレスの場合' do
              before do
                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                  .with(body: { email: valid_email })
                  .to_return(
                    status: 200,
                    body: {
                      data: {
                        reset_link: reset_link
                      }
                    }.to_json
                  )
              end
        
              it 'パスワードリセットリンクを返す' do
                result = described_class.generate_password_reset_link(valid_email)
                expect(result[:reset_link]).to eq(reset_link)
              end
            end
        
            context '無効なメールアドレスの場合' do
              before do
                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                  .with(body: { email: 'invalid@example.com' })
                  .to_return(status: 404, body: { error: 'User not found' }.to_json)
              end
        
              it 'nilを返す' do
                expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
              end
            end
        
            context 'Supabase APIエラーの場合' do
              before do
                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                  .to_return(status: 500)
              end
        
              it 'nilを返す' do
                expect(described_class.generate_password_reset_link(valid_email)).to be_nil
              end
            end
          
            describe '.refresh_token' do
              let(:valid_refresh_token) { 'valid_refresh_token' }
              let(:new_access_token) { 'new_access_token' }
              let(:new_refresh_token) { 'new_refresh_token' }
          
              context '有効なリフレッシュトークンの場合' do
                before do
                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                    .with(body: { refresh_token: valid_refresh_token })
                    .to_return(
                      status: 200,
                      body: {
                        access_token: new_access_token,
                        refresh_token: new_refresh_token
                      }.to_json
                    )
                end
          
                it '新しいアクセストークンとリフレッシュトークンを返す' do
                  result = described_class.refresh_token(valid_refresh_token)
                  expect(result[:access_token]).to eq(new_access_token)
                  expect(result[:refresh_token]).to eq(new_refresh_token)
                end
              end
          
              context '無効なリフレッシュトークンの場合' do
                before do
                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                    .with(body: { refresh_token: 'invalid_token' })
                    .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                end
          
                it 'nilを返す' do
                  expect(described_class.refresh_token('invalid_token')).to be_nil
                end
              end
          
              context 'Supabase APIエラーの場合' do
                before do
                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                    .to_return(status: 500)
                end
          
                it 'nilを返す' do
                  expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                end
              end
            
              describe '.generate_password_reset_link' do
                let(:valid_email) { 'user@example.com' }
                let(:reset_link) { 'https://example.com/reset-password' }
            
                context '有効なメールアドレスの場合' do
                  before do
                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                      .with(body: { email: valid_email })
                      .to_return(
                        status: 200,
                        body: { link: reset_link }.to_json
                      )
                  end
            
                  it 'パスワードリセットリンクを返す' do
                    result = described_class.generate_password_reset_link(valid_email)
                    expect(result[:link]).to eq(reset_link)
                  end
                end
            
                context '無効なメールアドレスの場合' do
                  before do
                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                      .with(body: { email: 'invalid@example.com' })
                      .to_return(status: 404, body: { error: 'User not found' }.to_json)
                  end
            
                  it 'nilを返す' do
                    expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                  end
                end
            
                context 'Supabase APIエラーの場合' do
                  before do
                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                      .to_return(status: 500)
                  end
            
                  it 'nilを返す' do
                    expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                  end
                end
              
                describe '.refresh_token' do
                  let(:valid_refresh_token) { 'valid_refresh_token' }
                  let(:new_access_token) { 'new_access_token' }
                  let(:new_refresh_token) { 'new_refresh_token' }
              
                  context '有効なリフレッシュトークンの場合' do
                    before do
                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                        .with(body: { grant_type: 'refresh_token', refresh_token: valid_refresh_token })
                        .to_return(
                          status: 200,
                          body: {
                            access_token: new_access_token,
                            refresh_token: new_refresh_token
                          }.to_json
                        )
                    end
              
                    it '新しいアクセストークンとリフレッシュトークンを返す' do
                      result = described_class.refresh_token(valid_refresh_token)
                      expect(result[:access_token]).to eq(new_access_token)
                      expect(result[:refresh_token]).to eq(new_refresh_token)
                    end
                  end
              
                  context '無効なリフレッシュトークンの場合' do
                    before do
                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                        .with(body: { grant_type: 'refresh_token', refresh_token: 'invalid_token' })
                        .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                    end
              
                    it 'nilを返す' do
                      expect(described_class.refresh_token('invalid_token')).to be_nil
                    end
                  end
              
                  context 'Supabase APIエラーの場合' do
                    before do
                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                        .to_return(status: 500)
                    end
              
                    it 'nilを返す' do
                      expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                    end
                  end
                
                  describe '.generate_password_reset_link' do
                    let(:valid_email) { 'user@example.com' }
                    let(:reset_link) { 'https://example.com/reset-password' }
                
                    context '有効なメールアドレスの場合' do
                      before do
                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                          .with(body: { email: valid_email })
                          .to_return(
                            status: 200,
                            body: {
                              reset_link: reset_link
                            }.to_json
                          )
                      end
                
                      it 'パスワードリセットリンクを返す' do
                        result = described_class.generate_password_reset_link(valid_email)
                        expect(result[:reset_link]).to eq(reset_link)
                      end
                    end
                
                    context '無効なメールアドレスの場合' do
                      before do
                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                          .with(body: { email: 'invalid@example.com' })
                          .to_return(status: 404, body: { error: 'User not found' }.to_json)
                      end
                
                      it 'nilを返す' do
                        expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                      end
                    end
                
                    context 'Supabase APIエラーの場合' do
                      before do
                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                          .to_return(status: 500)
                      end
                
                      it 'nilを返す' do
                        expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                      end
                    end
                  
                    describe '.refresh_token' do
                      let(:valid_refresh_token) { 'valid_refresh_token' }
                      let(:new_access_token) { 'new_access_token' }
                      let(:new_refresh_token) { 'new_refresh_token' }
                  
                      context '有効なリフレッシュトークンの場合' do
                        before do
                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                            .with(
                              body: {
                                grant_type: 'refresh_token',
                                refresh_token: valid_refresh_token
                              }
                            )
                            .to_return(
                              status: 200,
                              body: {
                                access_token: new_access_token,
                                refresh_token: new_refresh_token
                              }.to_json
                            )
                        end
                  
                        it '新しいトークンペアを返す' do
                          result = described_class.refresh_token(valid_refresh_token)
                          expect(result[:access_token]).to eq(new_access_token)
                          expect(result[:refresh_token]).to eq(new_refresh_token)
                        end
                      end
                  
                      context '無効なリフレッシュトークンの場合' do
                        before do
                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                            .with(
                              body: {
                                grant_type: 'refresh_token',
                                refresh_token: 'invalid_token'
                              }
                            )
                            .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                        end
                  
                        it 'nilを返す' do
                          expect(described_class.refresh_token('invalid_token')).to be_nil
                        end
                      end
                  
                      context 'Supabase APIエラーの場合' do
                        before do
                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                            .to_return(status: 500)
                        end
                  
                        it 'nilを返す' do
                          expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                        end
                      end
                    
                      describe '.generate_password_reset_link' do
                        let(:valid_email) { 'user@example.com' }
                        let(:reset_link) { 'https://example.com/reset-password' }
                    
                        context '有効なメールアドレスの場合' do
                          before do
                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                              .with(
                                body: {
                                  email: valid_email
                                }
                              )
                              .to_return(
                                status: 200,
                                body: {
                                  reset_link: reset_link
                                }.to_json
                              )
                          end
                    
                          it 'パスワードリセットリンクを返す' do
                            result = described_class.generate_password_reset_link(valid_email)
                            expect(result[:reset_link]).to eq(reset_link)
                          end
                        end
                    
                        context '無効なメールアドレスの場合' do
                          before do
                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                              .with(
                                body: {
                                  email: 'invalid@example.com'
                                }
                              )
                              .to_return(status: 404, body: { error: 'User not found' }.to_json)
                          end
                    
                          it 'nilを返す' do
                            expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                          end
                        end
                    
                        context 'Supabase APIエラーの場合' do
                          before do
                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                              .to_return(status: 500)
                          end
                    
                          it 'nilを返す' do
                            expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                          end
                        end
                      
                        describe '.refresh_token' do
                          let(:valid_refresh_token) { 'valid_refresh_token' }
                          let(:new_access_token) { 'new_access_token' }
                          let(:new_refresh_token) { 'new_refresh_token' }
                      
                          context '有効なリフレッシュトークンの場合' do
                            before do
                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                .with(
                                  body: {
                                    refresh_token: valid_refresh_token
                                  }
                                )
                                .to_return(
                                  status: 200,
                                  body: {
                                    access_token: new_access_token,
                                    refresh_token: new_refresh_token
                                  }.to_json
                                )
                            end
                      
                            it '新しいアクセストークンとリフレッシュトークンを返す' do
                              result = described_class.refresh_token(valid_refresh_token)
                              expect(result[:access_token]).to eq(new_access_token)
                              expect(result[:refresh_token]).to eq(new_refresh_token)
                            end
                          end
                      
                          context '無効なリフレッシュトークンの場合' do
                            before do
                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                .with(
                                  body: {
                                    refresh_token: 'invalid_refresh_token'
                                  }
                                )
                                .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                            end
                      
                            it 'nilを返す' do
                              expect(described_class.refresh_token('invalid_refresh_token')).to be_nil
                            end
                          end
                      
                          context 'Supabase APIエラーの場合' do
                            before do
                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                .to_return(status: 500)
                            end
                      
                            it 'nilを返す' do
                              expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                            end
                          end
                        
                          describe '.generate_password_reset_link' do
                            let(:valid_email) { 'user@example.com' }
                            let(:reset_link) { 'https://example.com/reset-password?token=abc123' }
                        
                            context '有効なメールアドレスの場合' do
                              before do
                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                  .with(
                                    body: {
                                      email: valid_email
                                    }
                                  )
                                  .to_return(
                                    status: 200,
                                    body: {
                                      data: {
                                        reset_link: reset_link
                                      }
                                    }.to_json
                                  )
                              end
                        
                              it 'パスワードリセットリンクを返す' do
                                result = described_class.generate_password_reset_link(valid_email)
                                expect(result[:reset_link]).to eq(reset_link)
                              end
                            end
                        
                            context '無効なメールアドレスの場合' do
                              before do
                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                  .with(
                                    body: {
                                      email: 'invalid@example.com'
                                    }
                                  )
                                  .to_return(status: 404, body: { error: 'User not found' }.to_json)
                              end
                        
                              it 'nilを返す' do
                                expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                              end
                            end
                        
                            context 'Supabase APIエラーの場合' do
                              before do
                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                  .to_return(status: 500)
                              end
                        
                              it 'nilを返す' do
                                expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                              end
                            end
                          
                            describe '.refresh_token' do
                              let(:valid_refresh_token) { 'valid_refresh_token' }
                              let(:new_access_token) { 'new_access_token' }
                              let(:new_refresh_token) { 'new_refresh_token' }
                          
                              context '有効なリフレッシュトークンの場合' do
                                before do
                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                    .with(
                                      body: {
                                        refresh_token: valid_refresh_token
                                      }
                                    )
                                    .to_return(
                                      status: 200,
                                      body: {
                                        access_token: new_access_token,
                                        refresh_token: new_refresh_token
                                      }.to_json
                                    )
                                end
                          
                                it '新しいアクセストークンとリフレッシュトークンを返す' do
                                  result = described_class.refresh_token(valid_refresh_token)
                                  expect(result[:access_token]).to eq(new_access_token)
                                  expect(result[:refresh_token]).to eq(new_refresh_token)
                                end
                              end
                          
                              context '無効なリフレッシュトークンの場合' do
                                before do
                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                    .with(
                                      body: {
                                        refresh_token: 'invalid_refresh_token'
                                      }
                                    )
                                    .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                end
                          
                                it 'nilを返す' do
                                  expect(described_class.refresh_token('invalid_refresh_token')).to be_nil
                                end
                              end
                          
                              context 'Supabase APIエラーの場合' do
                                before do
                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                    .to_return(status: 500)
                                end
                          
                                it 'nilを返す' do
                                  expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                end
                              end
                            
                              describe '.generate_password_reset_link' do
                                let(:valid_email) { 'user@example.com' }
                                let(:reset_link) { 'https://example.com/reset-password' }
                            
                                context '有効なメールアドレスの場合' do
                                  before do
                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                      .with(
                                        body: {
                                          email: valid_email
                                        }
                                      )
                                      .to_return(
                                        status: 200,
                                        body: {
                                          reset_link: reset_link
                                        }.to_json
                                      )
                                  end
                            
                                  it 'パスワードリセットリンクを返す' do
                                    result = described_class.generate_password_reset_link(valid_email)
                                    expect(result[:reset_link]).to eq(reset_link)
                                  end
                                end
                            
                                context '無効なメールアドレスの場合' do
                                  before do
                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                      .with(
                                        body: {
                                          email: 'invalid@example.com'
                                        }
                                      )
                                      .to_return(status: 404, body: { error: 'User not found' }.to_json)
                                  end
                            
                                  it 'nilを返す' do
                                    expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                                  end
                                end
                            
                                context 'Supabase APIエラーの場合' do
                                  before do
                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                      .to_return(status: 500)
                                  end
                            
                                  it 'nilを返す' do
                                    expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                  end
                                end
                              
                                describe '.refresh_token' do
                                  let(:valid_refresh_token) { 'valid_refresh_token' }
                                  let(:new_access_token) { 'new_access_token' }
                                  let(:new_refresh_token) { 'new_refresh_token' }
                              
                                  context '有効なリフレッシュトークンの場合' do
                                    before do
                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                        .with(
                                          body: {
                                            grant_type: 'refresh_token',
                                            refresh_token: valid_refresh_token
                                          }
                                        )
                                        .to_return(
                                          status: 200,
                                          body: {
                                            access_token: new_access_token,
                                            refresh_token: new_refresh_token
                                          }.to_json
                                        )
                                    end
                              
                                    it '新しいアクセストークンとリフレッシュトークンを返す' do
                                      result = described_class.refresh_token(valid_refresh_token)
                                      expect(result[:access_token]).to eq(new_access_token)
                                      expect(result[:refresh_token]).to eq(new_refresh_token)
                                    end
                                  end
                              
                                  context '無効なリフレッシュトークンの場合' do
                                    before do
                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                        .with(
                                          body: {
                                            grant_type: 'refresh_token',
                                            refresh_token: 'invalid_token'
                                          }
                                        )
                                        .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                    end
                              
                                    it 'nilを返す' do
                                      expect(described_class.refresh_token('invalid_token')).to be_nil
                                    end
                                  end
                              
                                  context 'Supabase APIエラーの場合' do
                                    before do
                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                        .to_return(status: 500)
                                    end
                              
                                    it 'nilを返す' do
                                      expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                    end
                                  end
                                
                                  describe '.generate_password_reset_link' do
                                    let(:valid_email) { 'user@example.com' }
                                    let(:reset_link) { 'https://example.com/reset-password' }
                                
                                    context '有効なメールアドレスの場合' do
                                      before do
                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                          .with(
                                            body: {
                                              email: valid_email
                                            }
                                          )
                                          .to_return(
                                            status: 200,
                                            body: {
                                              data: {
                                                reset_link: reset_link
                                              }
                                            }.to_json
                                          )
                                      end
                                
                                      it 'パスワードリセットリンクを返す' do
                                        result = described_class.generate_password_reset_link(valid_email)
                                        expect(result[:reset_link]).to eq(reset_link)
                                      end
                                    end
                                
                                    context '無効なメールアドレスの場合' do
                                      before do
                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                          .with(
                                            body: {
                                              email: 'invalid@example.com'
                                            }
                                          )
                                          .to_return(status: 404, body: { error: 'User not found' }.to_json)
                                      end
                                
                                      it 'nilを返す' do
                                        expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                                      end
                                    end
                                
                                    context 'Supabase APIエラーの場合' do
                                      before do
                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                          .to_return(status: 500)
                                      end
                                
                                      it 'nilを返す' do
                                        expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                      end
                                    end
                                  
                                    describe '.refresh_token' do
                                      let(:valid_refresh_token) { 'valid_refresh_token' }
                                      let(:new_access_token) { 'new_access_token' }
                                      let(:new_refresh_token) { 'new_refresh_token' }
                                  
                                      context '有効なリフレッシュトークンの場合' do
                                        before do
                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                            .with(
                                              body: {
                                                refresh_token: valid_refresh_token
                                              }
                                            )
                                            .to_return(
                                              status: 200,
                                              body: {
                                                access_token: new_access_token,
                                                refresh_token: new_refresh_token
                                              }.to_json
                                            )
                                        end
                                  
                                        it '新しいアクセストークンとリフレッシュトークンを返す' do
                                          result = described_class.refresh_token(valid_refresh_token)
                                          expect(result[:access_token]).to eq(new_access_token)
                                          expect(result[:refresh_token]).to eq(new_refresh_token)
                                        end
                                      end
                                  
                                      context '無効なリフレッシュトークンの場合' do
                                        before do
                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                            .with(
                                              body: {
                                                refresh_token: 'invalid_token'
                                              }
                                            )
                                            .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                        end
                                  
                                        it 'nilを返す' do
                                          expect(described_class.refresh_token('invalid_token')).to be_nil
                                        end
                                      end
                                  
                                      context 'Supabase APIエラーの場合' do
                                        before do
                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                            .to_return(status: 500)
                                        end
                                  
                                        it 'nilを返す' do
                                          expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                        end
                                      end
                                    
                                      describe '.generate_password_reset_link' do
                                        let(:valid_email) { 'user@example.com' }
                                        let(:reset_link) { 'https://example.com/reset-password' }
                                    
                                        context '有効なメールアドレスの場合' do
                                          before do
                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                              .with(
                                                body: {
                                                  email: valid_email
                                                }
                                              )
                                              .to_return(
                                                status: 200,
                                                body: {
                                                  reset_link: reset_link
                                                }.to_json
                                              )
                                          end
                                    
                                          it 'パスワードリセットリンクを返す' do
                                            result = described_class.generate_password_reset_link(valid_email)
                                            expect(result[:reset_link]).to eq(reset_link)
                                          end
                                        end
                                    
                                        context '無効なメールアドレスの場合' do
                                          before do
                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                              .with(
                                                body: {
                                                  email: 'invalid@example.com'
                                                }
                                              )
                                              .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                          end
                                    
                                          it 'nilを返す' do
                                            expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                                          end
                                        end
                                    
                                        context 'Supabase APIエラーの場合' do
                                          before do
                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                              .to_return(status: 500)
                                          end
                                    
                                          it 'nilを返す' do
                                            expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                          end
                                        end
                                      
                                        describe '.refresh_token' do
                                          let(:valid_refresh_token) { 'valid_refresh_token' }
                                          let(:new_access_token) { 'new_access_token' }
                                          let(:new_refresh_token) { 'new_refresh_token' }
                                      
                                          context '有効なリフレッシュトークンの場合' do
                                            before do
                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                .with(
                                                  body: {
                                                    grant_type: 'refresh_token',
                                                    refresh_token: valid_refresh_token
                                                  }
                                                )
                                                .to_return(
                                                  status: 200,
                                                  body: {
                                                    access_token: new_access_token,
                                                    refresh_token: new_refresh_token
                                                  }.to_json
                                                )
                                            end
                                      
                                            it '新しいアクセストークンとリフレッシュトークンを返す' do
                                              result = described_class.refresh_token(valid_refresh_token)
                                              expect(result[:access_token]).to eq(new_access_token)
                                              expect(result[:refresh_token]).to eq(new_refresh_token)
                                            end
                                          end
                                      
                                          context '無効なリフレッシュトークンの場合' do
                                            before do
                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                .with(
                                                  body: {
                                                    grant_type: 'refresh_token',
                                                    refresh_token: 'invalid_token'
                                                  }
                                                )
                                                .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                            end
                                      
                                            it 'nilを返す' do
                                              expect(described_class.refresh_token('invalid_token')).to be_nil
                                            end
                                          end
                                      
                                          context 'Supabase APIエラーの場合' do
                                            before do
                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                .to_return(status: 500)
                                            end
                                      
                                            it 'nilを返す' do
                                              expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                            end
                                          end
                                        
                                          describe '.generate_password_reset_link' do
                                            let(:valid_email) { 'user@example.com' }
                                            let(:reset_link) { 'https://example.com/reset-password' }
                                        
                                            context '有効なメールアドレスの場合' do
                                              before do
                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                  .with(
                                                    body: {
                                                      email: valid_email
                                                    }
                                                  )
                                                  .to_return(
                                                    status: 200,
                                                    body: {
                                                      data: {
                                                        reset_link: reset_link
                                                      }
                                                    }.to_json
                                                  )
                                              end
                                        
                                              it 'パスワードリセットリンクを返す' do
                                                result = described_class.generate_password_reset_link(valid_email)
                                                expect(result[:reset_link]).to eq(reset_link)
                                              end
                                            end
                                        
                                            context '無効なメールアドレスの場合' do
                                              before do
                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                  .with(
                                                    body: {
                                                      email: 'invalid@example.com'
                                                    }
                                                  )
                                                  .to_return(status: 404, body: { error: 'User not found' }.to_json)
                                              end
                                        
                                              it 'nilを返す' do
                                                expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                                              end
                                            end
                                        
                                            context 'Supabase APIエラーの場合' do
                                              before do
                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                  .to_return(status: 500)
                                              end
                                        
                                              it 'nilを返す' do
                                                expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                              end
                                            end
                                          
                                            describe '.refresh_token' do
                                              let(:valid_refresh_token) { 'valid_refresh_token' }
                                              let(:new_access_token) { 'new_access_token' }
                                              let(:new_refresh_token) { 'new_refresh_token' }
                                          
                                              context '有効なリフレッシュトークンの場合' do
                                                before do
                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                    .with(
                                                      body: {
                                                        refresh_token: valid_refresh_token
                                                      }
                                                    )
                                                    .to_return(
                                                      status: 200,
                                                      body: {
                                                        access_token: new_access_token,
                                                        refresh_token: new_refresh_token,
                                                        expires_in: 3600
                                                      }.to_json
                                                    )
                                                end
                                          
                                                it '新しいアクセストークンとリフレッシュトークンを返す' do
                                                  result = described_class.refresh_token(valid_refresh_token)
                                                  expect(result[:access_token]).to eq(new_access_token)
                                                  expect(result[:refresh_token]).to eq(new_refresh_token)
                                                end
                                              end
                                          
                                              context '無効なリフレッシュトークンの場合' do
                                                before do
                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                    .with(
                                                      body: {
                                                        refresh_token: 'invalid_refresh_token'
                                                      }
                                                    )
                                                    .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                end
                                          
                                                it 'nilを返す' do
                                                  expect(described_class.refresh_token('invalid_refresh_token')).to be_nil
                                                end
                                              end
                                          
                                              context 'Supabase APIエラーの場合' do
                                                before do
                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                    .to_return(status: 500)
                                                end
                                          
                                                it 'nilを返す' do
                                                  expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                end
                                              end
                                            
                                              describe '.generate_password_reset_link' do
                                                let(:valid_email) { 'user@example.com' }
                                                let(:reset_link) { 'https://example.com/reset-password' }
                                            
                                                context '有効なメールアドレスの場合' do
                                                  before do
                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                      .with(
                                                        body: {
                                                          email: valid_email
                                                        }
                                                      )
                                                      .to_return(
                                                        status: 200,
                                                        body: {
                                                          reset_link: reset_link
                                                        }.to_json
                                                      )
                                                  end
                                            
                                                  it 'パスワードリセットリンクを返す' do
                                                    result = described_class.generate_password_reset_link(valid_email)
                                                    expect(result[:reset_link]).to eq(reset_link)
                                                  end
                                                end
                                            
                                                context '無効なメールアドレスの場合' do
                                                  before do
                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                      .with(
                                                        body: {
                                                          email: 'invalid@example.com'
                                                        }
                                                      )
                                                      .to_return(status: 404, body: { error: 'User not found' }.to_json)
                                                  end
                                            
                                                  it 'nilを返す' do
                                                    expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                                                  end
                                                end
                                            
                                                context 'Supabase APIエラーの場合' do
                                                  before do
                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                      .to_return(status: 500)
                                                  end
                                            
                                                  it 'nilを返す' do
                                                    expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                                  end
                                                end
                                              
                                                describe '.refresh_token' do
                                                  let(:valid_refresh_token) { 'valid_refresh_token' }
                                                  let(:new_access_token) { 'new_access_token' }
                                                  let(:new_refresh_token) { 'new_refresh_token' }
                                              
                                                  context '有効なリフレッシュトークンの場合' do
                                                    before do
                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                        .with(
                                                          body: {
                                                            refresh_token: valid_refresh_token
                                                          }
                                                        )
                                                        .to_return(
                                                          status: 200,
                                                          body: {
                                                            access_token: new_access_token,
                                                            refresh_token: new_refresh_token
                                                          }.to_json
                                                        )
                                                    end
                                              
                                                    it '新しいアクセストークンとリフレッシュトークンを返す' do
                                                      result = described_class.refresh_token(valid_refresh_token)
                                                      expect(result[:access_token]).to eq(new_access_token)
                                                      expect(result[:refresh_token]).to eq(new_refresh_token)
                                                    end
                                                  end
                                              
                                                  context '無効なリフレッシュトークンの場合' do
                                                    before do
                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                        .with(
                                                          body: {
                                                            refresh_token: 'invalid_token'
                                                          }
                                                        )
                                                        .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                    end
                                              
                                                    it 'nilを返す' do
                                                      expect(described_class.refresh_token('invalid_token')).to be_nil
                                                    end
                                                  end
                                              
                                                  context 'Supabase APIエラーの場合' do
                                                    before do
                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                        .to_return(status: 500)
                                                    end
                                              
                                                    it 'nilを返す' do
                                                      expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                    end
                                                  end
                                                
                                                  describe '.generate_password_reset_link' do
                                                    let(:valid_email) { 'user@example.com' }
                                                    let(:reset_link) { 'https://example.com/reset-password' }
                                                
                                                    context '有効なメールアドレスの場合' do
                                                      before do
                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                          .with(
                                                            body: {
                                                              email: valid_email
                                                            }
                                                          )
                                                          .to_return(
                                                            status: 200,
                                                            body: {
                                                              data: {
                                                                reset_link: reset_link
                                                              }
                                                            }.to_json
                                                          )
                                                      end
                                                
                                                      it 'パスワードリセットリンクを返す' do
                                                        result = described_class.generate_password_reset_link(valid_email)
                                                        expect(result[:reset_link]).to eq(reset_link)
                                                      end
                                                    end
                                                
                                                    context '無効なメールアドレスの場合' do
                                                      before do
                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                          .with(
                                                            body: {
                                                              email: 'invalid_email'
                                                            }
                                                          )
                                                          .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                      end
                                                
                                                      it 'nilを返す' do
                                                        expect(described_class.generate_password_reset_link('invalid_email')).to be_nil
                                                      end
                                                    end
                                                
                                                    context 'Supabase APIエラーの場合' do
                                                      before do
                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                          .to_return(status: 500)
                                                      end
                                                
                                                      it 'nilを返す' do
                                                        expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                                      end
                                                    end
                                                  
                                                    describe '.refresh_token' do
                                                      let(:valid_refresh_token) { 'valid_refresh_token' }
                                                      let(:new_access_token) { 'new_access_token' }
                                                      let(:new_refresh_token) { 'new_refresh_token' }
                                                  
                                                      context '有効なリフレッシュトークンの場合' do
                                                        before do
                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                            .with(
                                                              body: {
                                                                grant_type: 'refresh_token',
                                                                refresh_token: valid_refresh_token
                                                              }
                                                            )
                                                            .to_return(
                                                              status: 200,
                                                              body: {
                                                                access_token: new_access_token,
                                                                refresh_token: new_refresh_token
                                                              }.to_json
                                                            )
                                                        end
                                                  
                                                        it '新しいアクセストークンとリフレッシュトークンを返す' do
                                                          result = described_class.refresh_token(valid_refresh_token)
                                                          expect(result[:access_token]).to eq(new_access_token)
                                                          expect(result[:refresh_token]).to eq(new_refresh_token)
                                                        end
                                                      end
                                                  
                                                      context '無効なリフレッシュトークンの場合' do
                                                        before do
                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                            .with(
                                                              body: {
                                                                grant_type: 'refresh_token',
                                                                refresh_token: 'invalid_token'
                                                              }
                                                            )
                                                            .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                        end
                                                  
                                                        it 'nilを返す' do
                                                          expect(described_class.refresh_token('invalid_token')).to be_nil
                                                        end
                                                      end
                                                  
                                                      context 'Supabase APIエラーの場合' do
                                                        before do
                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                            .to_return(status: 500)
                                                        end
                                                  
                                                        it 'nilを返す' do
                                                          expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                        end
                                                      end
                                                    
                                                      describe '.generate_password_reset_link' do
                                                        let(:valid_email) { 'user@example.com' }
                                                        let(:reset_link) { 'https://example.com/reset-password' }
                                                    
                                                        context '有効なメールアドレスの場合' do
                                                          before do
                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                              .with(
                                                                body: {
                                                                  email: valid_email
                                                                }
                                                              )
                                                              .to_return(
                                                                status: 200,
                                                                body: {
                                                                  data: {
                                                                    reset_link: reset_link
                                                                  }
                                                                }.to_json
                                                              )
                                                          end
                                                    
                                                          it 'パスワードリセットリンクを返す' do
                                                            result = described_class.generate_password_reset_link(valid_email)
                                                            expect(result[:reset_link]).to eq(reset_link)
                                                          end
                                                        end
                                                    
                                                        context '無効なメールアドレスの場合' do
                                                          before do
                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                              .with(
                                                                body: {
                                                                  email: 'invalid@example.com'
                                                                }
                                                              )
                                                              .to_return(status: 404, body: { error: 'User not found' }.to_json)
                                                          end
                                                    
                                                          it 'nilを返す' do
                                                            expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                                                          end
                                                        end
                                                    
                                                        context 'Supabase APIエラーの場合' do
                                                          before do
                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                              .to_return(status: 500)
                                                          end
                                                    
                                                          it 'nilを返す' do
                                                            expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                                          end
                                                        end
                                                      
                                                        describe '.refresh_token' do
                                                          let(:valid_refresh_token) { 'valid_refresh_token' }
                                                          let(:new_access_token) { 'new_access_token' }
                                                      
                                                          context '有効なリフレッシュトークンの場合' do
                                                            before do
                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                .with(
                                                                  body: {
                                                                    refresh_token: valid_refresh_token
                                                                  }
                                                                )
                                                                .to_return(
                                                                  status: 200,
                                                                  body: {
                                                                    access_token: new_access_token,
                                                                    expires_in: 3600
                                                                  }.to_json
                                                                )
                                                            end
                                                      
                                                            it '新しいアクセストークンを返す' do
                                                              result = described_class.refresh_token(valid_refresh_token)
                                                              expect(result[:access_token]).to eq(new_access_token)
                                                            end
                                                          end
                                                      
                                                          context '無効なリフレッシュトークンの場合' do
                                                            before do
                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                .with(
                                                                  body: {
                                                                    refresh_token: 'invalid_token'
                                                                  }
                                                                )
                                                                .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                            end
                                                      
                                                            it 'nilを返す' do
                                                              expect(described_class.refresh_token('invalid_token')).to be_nil
                                                            end
                                                          end
                                                      
                                                          context 'Supabase APIエラーの場合' do
                                                            before do
                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                .to_return(status: 500)
                                                            end
                                                      
                                                            it 'nilを返す' do
                                                              expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                            end
                                                          end
                                                        
                                                          describe '.generate_password_reset_link' do
                                                            let(:valid_email) { 'user@example.com' }
                                                            let(:reset_link) { 'https://example.com/reset-password' }
                                                        
                                                            context '有効なメールアドレスの場合' do
                                                              before do
                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                  .with(
                                                                    body: {
                                                                      email: valid_email
                                                                    }
                                                                  )
                                                                  .to_return(
                                                                    status: 200,
                                                                    body: {
                                                                      data: {
                                                                        reset_link: reset_link
                                                                      }
                                                                    }.to_json
                                                                  )
                                                              end
                                                        
                                                              it 'パスワードリセットリンクを返す' do
                                                                result = described_class.generate_password_reset_link(valid_email)
                                                                expect(result[:reset_link]).to eq(reset_link)
                                                              end
                                                            end
                                                        
                                                            context '無効なメールアドレスの場合' do
                                                              before do
                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                  .with(
                                                                    body: {
                                                                      email: 'invalid@example.com'
                                                                    }
                                                                  )
                                                                  .to_return(status: 404, body: { error: 'User not found' }.to_json)
                                                              end
                                                        
                                                              it 'nilを返す' do
                                                                expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                                                              end
                                                            end
                                                        
                                                            context 'Supabase APIエラーの場合' do
                                                              before do
                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                  .to_return(status: 500)
                                                              end
                                                        
                                                              it 'nilを返す' do
                                                                expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                                              end
                                                            end
                                                          
                                                            describe '.refresh_token' do
                                                              let(:valid_refresh_token) { 'valid_refresh_token' }
                                                              let(:new_access_token) { 'new_access_token' }
                                                              let(:new_refresh_token) { 'new_refresh_token' }
                                                          
                                                              context '有効なリフレッシュトークンの場合' do
                                                                before do
                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                    .with(
                                                                      body: {
                                                                        refresh_token: valid_refresh_token
                                                                      }
                                                                    )
                                                                    .to_return(
                                                                      status: 200,
                                                                      body: {
                                                                        access_token: new_access_token,
                                                                        refresh_token: new_refresh_token
                                                                      }.to_json
                                                                    )
                                                                end
                                                          
                                                                it '新しいアクセストークンとリフレッシュトークンを返す' do
                                                                  result = described_class.refresh_token(valid_refresh_token)
                                                                  expect(result[:access_token]).to eq(new_access_token)
                                                                  expect(result[:refresh_token]).to eq(new_refresh_token)
                                                                end
                                                              end
                                                          
                                                              context '無効なリフレッシュトークンの場合' do
                                                                before do
                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                    .with(
                                                                      body: {
                                                                        refresh_token: 'invalid_token'
                                                                      }
                                                                    )
                                                                    .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                end
                                                          
                                                                it 'nilを返す' do
                                                                  expect(described_class.refresh_token('invalid_token')).to be_nil
                                                                end
                                                              end
                                                          
                                                              context 'Supabase APIエラーの場合' do
                                                                before do
                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                    .to_return(status: 500)
                                                                end
                                                          
                                                                it 'nilを返す' do
                                                                  expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                end
                                                              end
                                                            
                                                              describe '.generate_password_reset_link' do
                                                                let(:valid_email) { 'user@example.com' }
                                                                let(:reset_link) { 'https://example.com/reset-password' }
                                                            
                                                                context '有効なメールアドレスの場合' do
                                                                  before do
                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                      .with(
                                                                        body: {
                                                                          email: valid_email
                                                                        }
                                                                      )
                                                                      .to_return(
                                                                        status: 200,
                                                                        body: {
                                                                          reset_link: reset_link
                                                                        }.to_json
                                                                      )
                                                                  end
                                                            
                                                                  it 'パスワードリセットリンクを返す' do
                                                                    result = described_class.generate_password_reset_link(valid_email)
                                                                    expect(result[:reset_link]).to eq(reset_link)
                                                                  end
                                                                end
                                                            
                                                                context '無効なメールアドレスの場合' do
                                                                  before do
                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                      .with(
                                                                        body: {
                                                                          email: 'invalid@example.com'
                                                                        }
                                                                      )
                                                                      .to_return(status: 404, body: { error: 'User not found' }.to_json)
                                                                  end
                                                            
                                                                  it 'nilを返す' do
                                                                    expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                                                                  end
                                                                end
                                                            
                                                                context 'Supabase APIエラーの場合' do
                                                                  before do
                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                      .to_return(status: 500)
                                                                  end
                                                            
                                                                  it 'nilを返す' do
                                                                    expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                                                  end
                                                                end
                                                              
                                                                describe '.refresh_token' do
                                                                  let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                  let(:new_access_token) { 'new_access_token' }
                                                                  let(:new_refresh_token) { 'new_refresh_token' }
                                                              
                                                                  context '有効なリフレッシュトークンの場合' do
                                                                    before do
                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                        .with(
                                                                          body: {
                                                                            refresh_token: valid_refresh_token
                                                                          }
                                                                        )
                                                                        .to_return(
                                                                          status: 200,
                                                                          body: {
                                                                            access_token: new_access_token,
                                                                            refresh_token: new_refresh_token
                                                                          }.to_json
                                                                        )
                                                                    end
                                                              
                                                                    it '新しいアクセストークンとリフレッシュトークンを返す' do
                                                                      result = described_class.refresh_token(valid_refresh_token)
                                                                      expect(result[:access_token]).to eq(new_access_token)
                                                                      expect(result[:refresh_token]).to eq(new_refresh_token)
                                                                    end
                                                                  end
                                                              
                                                                  context '無効なリフレッシュトークンの場合' do
                                                                    before do
                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                        .with(
                                                                          body: {
                                                                            refresh_token: 'invalid_token'
                                                                          }
                                                                        )
                                                                        .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                    end
                                                              
                                                                    it 'nilを返す' do
                                                                      expect(described_class.refresh_token('invalid_token')).to be_nil
                                                                    end
                                                                  end
                                                              
                                                                  context 'Supabase APIエラーの場合' do
                                                                    before do
                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                        .to_return(status: 500)
                                                                    end
                                                              
                                                                    it 'nilを返す' do
                                                                      expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                    end
                                                                  end
                                                                
                                                                  describe '.generate_password_reset_link' do
                                                                    let(:valid_email) { 'user@example.com' }
                                                                    let(:reset_link) { 'https://example.com/reset-password' }
                                                                
                                                                    context '有効なメールアドレスの場合' do
                                                                      before do
                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                          .with(
                                                                            body: {
                                                                              email: valid_email
                                                                            }
                                                                          )
                                                                          .to_return(
                                                                            status: 200,
                                                                            body: {
                                                                              reset_link: reset_link
                                                                            }.to_json
                                                                          )
                                                                      end
                                                                
                                                                      it 'パスワードリセットリンクを返す' do
                                                                        result = described_class.generate_password_reset_link(valid_email)
                                                                        expect(result[:reset_link]).to eq(reset_link)
                                                                      end
                                                                    end
                                                                
                                                                    context '無効なメールアドレスの場合' do
                                                                      before do
                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                          .with(
                                                                            body: {
                                                                              email: 'invalid@example.com'
                                                                            }
                                                                          )
                                                                          .to_return(status: 404, body: { error: 'User not found' }.to_json)
                                                                      end
                                                                
                                                                      it 'nilを返す' do
                                                                        expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                                                                      end
                                                                    end
                                                                
                                                                    context 'Supabase APIエラーの場合' do
                                                                      before do
                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                          .to_return(status: 500)
                                                                      end
                                                                
                                                                      it 'nilを返す' do
                                                                        expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                                                      end
                                                                    end
                                                                  
                                                                    describe '.refresh_token' do
                                                                      let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                      let(:new_access_token) { 'new_access_token' }
                                                                      let(:new_refresh_token) { 'new_refresh_token' }
                                                                  
                                                                      context '有効なリフレッシュトークンの場合' do
                                                                        before do
                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                            .with(
                                                                              body: {
                                                                                grant_type: 'refresh_token',
                                                                                refresh_token: valid_refresh_token
                                                                              }
                                                                            )
                                                                            .to_return(
                                                                              status: 200,
                                                                              body: {
                                                                                access_token: new_access_token,
                                                                                refresh_token: new_refresh_token
                                                                              }.to_json
                                                                            )
                                                                        end
                                                                  
                                                                        it '新しいアクセストークンとリフレッシュトークンを返す' do
                                                                          result = described_class.refresh_token(valid_refresh_token)
                                                                          expect(result[:access_token]).to eq(new_access_token)
                                                                          expect(result[:refresh_token]).to eq(new_refresh_token)
                                                                        end
                                                                      end
                                                                  
                                                                      context '無効なリフレッシュトークンの場合' do
                                                                        before do
                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                            .with(
                                                                              body: {
                                                                                grant_type: 'refresh_token',
                                                                                refresh_token: 'invalid_token'
                                                                              }
                                                                            )
                                                                            .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                        end
                                                                  
                                                                        it 'nilを返す' do
                                                                          expect(described_class.refresh_token('invalid_token')).to be_nil
                                                                        end
                                                                      end
                                                                  
                                                                      context 'Supabase APIエラーの場合' do
                                                                        before do
                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                            .to_return(status: 500)
                                                                        end
                                                                  
                                                                        it 'nilを返す' do
                                                                          expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                        end
                                                                      end
                                                                    
                                                                      describe '.generate_password_reset_link' do
                                                                        let(:valid_email) { 'user@example.com' }
                                                                        let(:reset_link) { 'https://example.com/reset-password' }
                                                                    
                                                                        context '有効なメールアドレスの場合' do
                                                                          before do
                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                              .with(
                                                                                body: {
                                                                                  email: valid_email,
                                                                                  redirect_to: "#{ENV['FRONTEND_URL']}/auth/reset-password"
                                                                                }
                                                                              )
                                                                              .to_return(
                                                                                status: 200,
                                                                                body: { link: reset_link }.to_json
                                                                              )
                                                                          end
                                                                    
                                                                          it 'パスワードリセットリンクを返す' do
                                                                            result = described_class.generate_password_reset_link(valid_email)
                                                                            expect(result[:link]).to eq(reset_link)
                                                                          end
                                                                        end
                                                                    
                                                                        context '無効なメールアドレスの場合' do
                                                                          before do
                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                              .with(
                                                                                body: {
                                                                                  email: 'invalid@example.com',
                                                                                  redirect_to: "#{ENV['FRONTEND_URL']}/auth/reset-password"
                                                                                }
                                                                              )
                                                                              .to_return(status: 404, body: { error: 'User not found' }.to_json)
                                                                          end
                                                                    
                                                                          it 'nilを返す' do
                                                                            expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                                                                          end
                                                                        end
                                                                    
                                                                        context 'Supabase APIエラーの場合' do
                                                                          before do
                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                              .to_return(status: 500)
                                                                          end
                                                                    
                                                                          it 'nilを返す' do
                                                                            expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                                                          end
                                                                        end
                                                                      
                                                                        describe '.refresh_token' do
                                                                          let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                          let(:new_access_token) { 'new_access_token' }
                                                                          let(:new_refresh_token) { 'new_refresh_token' }
                                                                      
                                                                          context '有効なリフレッシュトークンの場合' do
                                                                            before do
                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                .with(
                                                                                  body: {
                                                                                    refresh_token: valid_refresh_token
                                                                                  }
                                                                                )
                                                                                .to_return(
                                                                                  status: 200,
                                                                                  body: {
                                                                                    access_token: new_access_token,
                                                                                    refresh_token: new_refresh_token
                                                                                  }.to_json
                                                                                )
                                                                            end
                                                                      
                                                                            it '新しいトークンペアを返す' do
                                                                              result = described_class.refresh_token(valid_refresh_token)
                                                                              expect(result[:access_token]).to eq(new_access_token)
                                                                              expect(result[:refresh_token]).to eq(new_refresh_token)
                                                                            end
                                                                          end
                                                                      
                                                                          context '無効なリフレッシュトークンの場合' do
                                                                            before do
                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                .with(
                                                                                  body: {
                                                                                    refresh_token: 'invalid_token'
                                                                                  }
                                                                                )
                                                                                .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                            end
                                                                      
                                                                            it 'nilを返す' do
                                                                              expect(described_class.refresh_token('invalid_token')).to be_nil
                                                                            end
                                                                          end
                                                                      
                                                                          context 'Supabase APIエラーの場合' do
                                                                            before do
                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                .to_return(status: 500)
                                                                            end
                                                                      
                                                                            it 'nilを返す' do
                                                                              expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                            end
                                                                          end
                                                                        
                                                                          describe '.generate_password_reset_link' do
                                                                            let(:valid_email) { 'user@example.com' }
                                                                            let(:reset_link) { 'https://example.com/reset-password' }
                                                                        
                                                                            context '有効なメールアドレスの場合' do
                                                                              before do
                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                  .with(
                                                                                    body: {
                                                                                      email: valid_email
                                                                                    }
                                                                                  )
                                                                                  .to_return(
                                                                                    status: 200,
                                                                                    body: {
                                                                                      reset_link: reset_link
                                                                                    }.to_json
                                                                                  )
                                                                              end
                                                                        
                                                                              it 'パスワードリセットリンクを返す' do
                                                                                result = described_class.generate_password_reset_link(valid_email)
                                                                                expect(result[:reset_link]).to eq(reset_link)
                                                                              end
                                                                            end
                                                                        
                                                                            context '無効なメールアドレスの場合' do
                                                                              before do
                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                  .with(
                                                                                    body: {
                                                                                      email: 'invalid@example.com'
                                                                                    }
                                                                                  )
                                                                                  .to_return(status: 404, body: { error: 'User not found' }.to_json)
                                                                              end
                                                                        
                                                                              it 'nilを返す' do
                                                                                expect(described_class.generate_password_reset_link('invalid@example.com')).to be_nil
                                                                              end
                                                                            end
                                                                        
                                                                            context 'Supabase APIエラーの場合' do
                                                                              before do
                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                  .to_return(status: 500)
                                                                              end
                                                                        
                                                                              it 'nilを返す' do
                                                                                expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                                                              end
                                                                            end
                                                                          
                                                                            describe '.refresh_token' do
                                                                              let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                              let(:new_access_token) { 'new_access_token' }
                                                                              let(:new_refresh_token) { 'new_refresh_token' }
                                                                          
                                                                              context '有効なリフレッシュトークンの場合' do
                                                                                before do
                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                    .with(
                                                                                      body: {
                                                                                        grant_type: 'refresh_token',
                                                                                        refresh_token: valid_refresh_token
                                                                                      }
                                                                                    )
                                                                                    .to_return(
                                                                                      status: 200,
                                                                                      body: {
                                                                                        access_token: new_access_token,
                                                                                        refresh_token: new_refresh_token
                                                                                      }.to_json
                                                                                    )
                                                                                end
                                                                          
                                                                                it '新しいアクセストークンとリフレッシュトークンを返す' do
                                                                                  result = described_class.refresh_token(valid_refresh_token)
                                                                                  expect(result[:access_token]).to eq(new_access_token)
                                                                                  expect(result[:refresh_token]).to eq(new_refresh_token)
                                                                                end
                                                                              end
                                                                          
                                                                              context '無効なリフレッシュトークンの場合' do
                                                                                before do
                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                    .with(
                                                                                      body: {
                                                                                        grant_type: 'refresh_token',
                                                                                        refresh_token: 'invalid_token'
                                                                                      }
                                                                                    )
                                                                                    .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                end
                                                                          
                                                                                it 'nilを返す' do
                                                                                  expect(described_class.refresh_token('invalid_token')).to be_nil
                                                                                end
                                                                              end
                                                                          
                                                                              context 'Supabase APIエラーの場合' do
                                                                                before do
                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                    .to_return(status: 500)
                                                                                end
                                                                          
                                                                                it 'nilを返す' do
                                                                                  expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                end
                                                                              end
                                                                            
                                                                              describe '.generate_password_reset_link' do
                                                                                let(:valid_email) { 'user@example.com' }
                                                                            
                                                                                context '有効なメールアドレスの場合' do
                                                                                  before do
                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                      .with(
                                                                                        body: {
                                                                                          email: valid_email
                                                                                        }
                                                                                      )
                                                                                      .to_return(status: 200, body: {}.to_json)
                                                                                  end
                                                                            
                                                                                  it 'trueを返す' do
                                                                                    expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                  end
                                                                                end
                                                                            
                                                                                context '無効なメールアドレスの場合' do
                                                                                  before do
                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                      .with(
                                                                                        body: {
                                                                                          email: 'invalid_email'
                                                                                        }
                                                                                      )
                                                                                      .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                  end
                                                                            
                                                                                  it 'falseを返す' do
                                                                                    expect(described_class.generate_password_reset_link('invalid_email')).to be false
                                                                                  end
                                                                                end
                                                                            
                                                                                context 'Supabase APIエラーの場合' do
                                                                                  before do
                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                      .to_return(status: 500)
                                                                                  end
                                                                            
                                                                                  it 'falseを返す' do
                                                                                    expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                  end
                                                                                end
                                                                              
                                                                                describe '.refresh_token' do
                                                                                  let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                  let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                              
                                                                                  context '有効なリフレッシュトークンの場合' do
                                                                                    before do
                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                        .with(
                                                                                          body: {
                                                                                            refresh_token: valid_refresh_token
                                                                                          }
                                                                                        )
                                                                                        .to_return(
                                                                                          status: 200,
                                                                                          body: {
                                                                                            access_token: 'new_access_token',
                                                                                            refresh_token: 'new_refresh_token'
                                                                                          }.to_json
                                                                                        )
                                                                                    end
                                                                              
                                                                                    it '新しいトークンデータを返す' do
                                                                                      result = described_class.refresh_token(valid_refresh_token)
                                                                                      expect(result).to include(
                                                                                        'access_token' => 'new_access_token',
                                                                                        'refresh_token' => 'new_refresh_token'
                                                                                      )
                                                                                    end
                                                                                  end
                                                                              
                                                                                  context '無効なリフレッシュトークンの場合' do
                                                                                    before do
                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                        .with(
                                                                                          body: {
                                                                                            refresh_token: invalid_refresh_token
                                                                                          }
                                                                                        )
                                                                                        .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                    end
                                                                              
                                                                                    it 'nilを返す' do
                                                                                      expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                    end
                                                                                  end
                                                                              
                                                                                  context 'Supabase APIエラーの場合' do
                                                                                    before do
                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                        .to_return(status: 500)
                                                                                    end
                                                                              
                                                                                    it 'nilを返す' do
                                                                                      expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                    end
                                                                                  end
                                                                                
                                                                                  describe '.generate_password_reset_link' do
                                                                                    let(:valid_email) { 'user@example.com' }
                                                                                    let(:invalid_email) { 'invalid' }
                                                                                
                                                                                    context '有効なメールアドレスの場合' do
                                                                                      before do
                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                          .with(
                                                                                            body: {
                                                                                              email: valid_email
                                                                                            }
                                                                                          )
                                                                                          .to_return(status: 200, body: {}.to_json)
                                                                                      end
                                                                                
                                                                                      it 'trueを返す' do
                                                                                        expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                      end
                                                                                    end
                                                                                
                                                                                    context '無効なメールアドレスの場合' do
                                                                                      before do
                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                          .with(
                                                                                            body: {
                                                                                              email: invalid_email
                                                                                            }
                                                                                          )
                                                                                          .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                      end
                                                                                
                                                                                      it 'falseを返す' do
                                                                                        expect(described_class.generate_password_reset_link(invalid_email)).to be false
                                                                                      end
                                                                                    end
                                                                                
                                                                                    context 'Supabase APIエラーの場合' do
                                                                                      before do
                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                          .to_return(status: 500)
                                                                                      end
                                                                                
                                                                                      it 'falseを返す' do
                                                                                        expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                      end
                                                                                    end
                                                                                  
                                                                                    describe '.refresh_token' do
                                                                                      let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                      let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                                  
                                                                                      context '有効なリフレッシュトークンの場合' do
                                                                                        before do
                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                            .with(
                                                                                              body: {
                                                                                                refresh_token: valid_refresh_token
                                                                                              }
                                                                                            )
                                                                                            .to_return(
                                                                                              status: 200,
                                                                                              body: {
                                                                                                access_token: 'new_access_token',
                                                                                                refresh_token: 'new_refresh_token'
                                                                                              }.to_json
                                                                                            )
                                                                                        end
                                                                                  
                                                                                        it '新しいトークンデータを返す' do
                                                                                          result = described_class.refresh_token(valid_refresh_token)
                                                                                          expect(result).to include(
                                                                                            access_token: 'new_access_token',
                                                                                            refresh_token: 'new_refresh_token'
                                                                                          )
                                                                                        end
                                                                                      end
                                                                                  
                                                                                      context '無効なリフレッシュトークンの場合' do
                                                                                        before do
                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                            .with(
                                                                                              body: {
                                                                                                refresh_token: invalid_refresh_token
                                                                                              }
                                                                                            )
                                                                                            .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                        end
                                                                                  
                                                                                        it 'nilを返す' do
                                                                                          expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                        end
                                                                                      end
                                                                                  
                                                                                      context 'Supabase APIエラーの場合' do
                                                                                        before do
                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                            .to_return(status: 500)
                                                                                        end
                                                                                  
                                                                                        it 'nilを返す' do
                                                                                          expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                        end
                                                                                      end
                                                                                    
                                                                                      describe '.generate_password_reset_link' do
                                                                                        let(:valid_email) { 'user@example.com' }
                                                                                        let(:invalid_email) { 'invalid' }
                                                                                    
                                                                                        context '有効なメールアドレスの場合' do
                                                                                          before do
                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                              .with(
                                                                                                body: {
                                                                                                  email: valid_email
                                                                                                }
                                                                                              )
                                                                                              .to_return(status: 200, body: {}.to_json)
                                                                                          end
                                                                                    
                                                                                          it 'trueを返す' do
                                                                                            expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                          end
                                                                                        end
                                                                                    
                                                                                        context '無効なメールアドレスの場合' do
                                                                                          before do
                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                              .with(
                                                                                                body: {
                                                                                                  email: invalid_email
                                                                                                }
                                                                                              )
                                                                                              .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                          end
                                                                                    
                                                                                          it 'falseを返す' do
                                                                                            expect(described_class.generate_password_reset_link(invalid_email)).to be false
                                                                                          end
                                                                                        end
                                                                                    
                                                                                        context 'Supabase APIエラーの場合' do
                                                                                          before do
                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                              .to_return(status: 500)
                                                                                          end
                                                                                    
                                                                                          it 'falseを返す' do
                                                                                            expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                          end
                                                                                        end
                                                                                      
                                                                                        describe '.refresh_token' do
                                                                                          let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                          let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                                      
                                                                                          context '有効なリフレッシュトークンの場合' do
                                                                                            before do
                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                .with(
                                                                                                  body: {
                                                                                                    refresh_token: valid_refresh_token
                                                                                                  }
                                                                                                )
                                                                                                .to_return(
                                                                                                  status: 200,
                                                                                                  body: {
                                                                                                    access_token: 'new_access_token',
                                                                                                    refresh_token: 'new_refresh_token',
                                                                                                    expires_in: 3600
                                                                                                  }.to_json
                                                                                                )
                                                                                            end
                                                                                      
                                                                                            it '新しいトークン情報を返す' do
                                                                                              result = described_class.refresh_token(valid_refresh_token)
                                                                                              expect(result[:access_token]).to eq 'new_access_token'
                                                                                              expect(result[:refresh_token]).to eq 'new_refresh_token'
                                                                                              expect(result[:expires_in]).to eq 3600
                                                                                            end
                                                                                          end
                                                                                      
                                                                                          context '無効なリフレッシュトークンの場合' do
                                                                                            before do
                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                .with(
                                                                                                  body: {
                                                                                                    refresh_token: invalid_refresh_token
                                                                                                  }
                                                                                                )
                                                                                                .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                            end
                                                                                      
                                                                                            it 'nilを返す' do
                                                                                              expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                            end
                                                                                          end
                                                                                      
                                                                                          context 'Supabase APIエラーの場合' do
                                                                                            before do
                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                .to_return(status: 500)
                                                                                            end
                                                                                      
                                                                                            it 'nilを返す' do
                                                                                              expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                            end
                                                                                          end
                                                                                        
                                                                                          describe '.generate_password_reset_link' do
                                                                                            let(:valid_email) { 'user@example.com' }
                                                                                            let(:invalid_email) { 'invalid@example.com' }
                                                                                        
                                                                                            context '有効なメールアドレスの場合' do
                                                                                              before do
                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                  .with(
                                                                                                    body: {
                                                                                                      email: valid_email
                                                                                                    }
                                                                                                  )
                                                                                                  .to_return(
                                                                                                    status: 200,
                                                                                                    body: {
                                                                                                      message: 'Password recovery email sent'
                                                                                                    }.to_json
                                                                                                  )
                                                                                              end
                                                                                        
                                                                                              it 'trueを返す' do
                                                                                                expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                              end
                                                                                            end
                                                                                        
                                                                                            context '無効なメールアドレスの場合' do
                                                                                              before do
                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                  .with(
                                                                                                    body: {
                                                                                                      email: invalid_email
                                                                                                    }
                                                                                                  )
                                                                                                  .to_return(status: 404, body: { error: 'User not found' }.to_json)
                                                                                              end
                                                                                        
                                                                                              it 'falseを返す' do
                                                                                                expect(described_class.generate_password_reset_link(invalid_email)).to be false
                                                                                              end
                                                                                            end
                                                                                        
                                                                                            context 'Supabase APIエラーの場合' do
                                                                                              before do
                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                  .to_return(status: 500)
                                                                                              end
                                                                                        
                                                                                              it 'falseを返す' do
                                                                                                expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                              end
                                                                                            end
                                                                                          
                                                                                            describe '.refresh_token' do
                                                                                              let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                              let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                                          
                                                                                              context '有効なリフレッシュトークンの場合' do
                                                                                                before do
                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                    .with(
                                                                                                      body: {
                                                                                                        refresh_token: valid_refresh_token
                                                                                                      }
                                                                                                    )
                                                                                                    .to_return(
                                                                                                      status: 200,
                                                                                                      body: {
                                                                                                        access_token: 'new_access_token',
                                                                                                        refresh_token: 'new_refresh_token',
                                                                                                        expires_in: 3600
                                                                                                      }.to_json
                                                                                                    )
                                                                                                end
                                                                                          
                                                                                                it '新しいトークンデータを返す' do
                                                                                                  result = described_class.refresh_token(valid_refresh_token)
                                                                                                  expect(result).to include(
                                                                                                    access_token: 'new_access_token',
                                                                                                    refresh_token: 'new_refresh_token',
                                                                                                    expires_in: 3600
                                                                                                  )
                                                                                                end
                                                                                              end
                                                                                          
                                                                                              context '無効なリフレッシュトークンの場合' do
                                                                                                before do
                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                    .with(
                                                                                                      body: {
                                                                                                        refresh_token: invalid_refresh_token
                                                                                                      }
                                                                                                    )
                                                                                                    .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                end
                                                                                          
                                                                                                it 'nilを返す' do
                                                                                                  expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                end
                                                                                              end
                                                                                          
                                                                                              context 'Supabase APIエラーの場合' do
                                                                                                before do
                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                    .to_return(status: 500)
                                                                                                end
                                                                                          
                                                                                                it 'nilを返す' do
                                                                                                  expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                end
                                                                                              end
                                                                                            
                                                                                              describe '.generate_password_reset_link' do
                                                                                                let(:valid_email) { 'user@example.com' }
                                                                                                let(:invalid_email) { 'invalid' }
                                                                                            
                                                                                                context '有効なメールアドレスの場合' do
                                                                                                  before do
                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                      .with(
                                                                                                        body: {
                                                                                                          email: valid_email
                                                                                                        }
                                                                                                      )
                                                                                                      .to_return(status: 200, body: {}.to_json)
                                                                                                  end
                                                                                            
                                                                                                  it 'trueを返す' do
                                                                                                    expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                                  end
                                                                                                end
                                                                                            
                                                                                                context '無効なメールアドレスの場合' do
                                                                                                  before do
                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                      .with(
                                                                                                        body: {
                                                                                                          email: invalid_email
                                                                                                        }
                                                                                                      )
                                                                                                      .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                  end
                                                                                            
                                                                                                  it 'falseを返す' do
                                                                                                    expect(described_class.generate_password_reset_link(invalid_email)).to be false
                                                                                                  end
                                                                                                end
                                                                                            
                                                                                                context 'Supabase APIエラーの場合' do
                                                                                                  before do
                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                      .to_return(status: 500)
                                                                                                  end
                                                                                            
                                                                                                  it 'falseを返す' do
                                                                                                    expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                                  end
                                                                                                end
                                                                                              
                                                                                                describe '.refresh_token' do
                                                                                                  let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                  let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                                              
                                                                                                  context '有効なリフレッシュトークンの場合' do
                                                                                                    before do
                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                        .with(
                                                                                                          body: {
                                                                                                            refresh_token: valid_refresh_token
                                                                                                          }
                                                                                                        )
                                                                                                        .to_return(
                                                                                                          status: 200,
                                                                                                          body: {
                                                                                                            access_token: 'new_access_token',
                                                                                                            refresh_token: 'new_refresh_token',
                                                                                                            expires_in: 3600
                                                                                                          }.to_json
                                                                                                        )
                                                                                                    end
                                                                                              
                                                                                                    it '新しいトークン情報を返す' do
                                                                                                      result = described_class.refresh_token(valid_refresh_token)
                                                                                                      expect(result[:access_token]).to eq('new_access_token')
                                                                                                      expect(result[:refresh_token]).to eq('new_refresh_token')
                                                                                                      expect(result[:expires_in]).to eq(3600)
                                                                                                    end
                                                                                                  end
                                                                                              
                                                                                                  context '無効なリフレッシュトークンの場合' do
                                                                                                    before do
                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                        .with(
                                                                                                          body: {
                                                                                                            refresh_token: invalid_refresh_token
                                                                                                          }
                                                                                                        )
                                                                                                        .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                    end
                                                                                              
                                                                                                    it 'nilを返す' do
                                                                                                      expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                    end
                                                                                                  end
                                                                                              
                                                                                                  context 'Supabase APIエラーの場合' do
                                                                                                    before do
                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                        .to_return(status: 500)
                                                                                                    end
                                                                                              
                                                                                                    it 'nilを返す' do
                                                                                                      expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                    end
                                                                                                  end
                                                                                                
                                                                                                  describe '.generate_password_reset_link' do
                                                                                                    let(:valid_email) { 'user@example.com' }
                                                                                                    let(:invalid_email) { 'invalid' }
                                                                                                
                                                                                                    context '有効なメールアドレスの場合' do
                                                                                                      before do
                                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                          .with(
                                                                                                            body: {
                                                                                                              email: valid_email
                                                                                                            }
                                                                                                          )
                                                                                                          .to_return(
                                                                                                            status: 200,
                                                                                                            body: {
                                                                                                              message: 'Password recovery email sent'
                                                                                                            }.to_json
                                                                                                          )
                                                                                                      end
                                                                                                
                                                                                                      it 'trueを返す' do
                                                                                                        expect(described_class.generate_password_reset_link(valid_email)).to be_truthy
                                                                                                      end
                                                                                                    end
                                                                                                
                                                                                                    context '無効なメールアドレスの場合' do
                                                                                                      before do
                                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                          .with(
                                                                                                            body: {
                                                                                                              email: invalid_email
                                                                                                            }
                                                                                                          )
                                                                                                          .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                      end
                                                                                                
                                                                                                      it 'falseを返す' do
                                                                                                        expect(described_class.generate_password_reset_link(invalid_email)).to be_falsey
                                                                                                      end
                                                                                                    end
                                                                                                
                                                                                                    context 'Supabase APIエラーの場合' do
                                                                                                      before do
                                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                          .to_return(status: 500)
                                                                                                      end
                                                                                                
                                                                                                      it 'falseを返す' do
                                                                                                        expect(described_class.generate_password_reset_link(valid_email)).to be_falsey
                                                                                                      end
                                                                                                    end
                                                                                                  
                                                                                                    describe '.refresh_token' do
                                                                                                      let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                      let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                                                  
                                                                                                      context '有効なリフレッシュトークンの場合' do
                                                                                                        before do
                                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                            .with(
                                                                                                              body: {
                                                                                                                refresh_token: valid_refresh_token
                                                                                                              }
                                                                                                            )
                                                                                                            .to_return(
                                                                                                              status: 200,
                                                                                                              body: {
                                                                                                                access_token: 'new_access_token',
                                                                                                                refresh_token: 'new_refresh_token',
                                                                                                                expires_in: 3600
                                                                                                              }.to_json
                                                                                                            )
                                                                                                        end
                                                                                                  
                                                                                                        it '新しいトークンデータを返す' do
                                                                                                          result = described_class.refresh_token(valid_refresh_token)
                                                                                                          expect(result[:access_token]).to eq('new_access_token')
                                                                                                          expect(result[:refresh_token]).to eq('new_refresh_token')
                                                                                                          expect(result[:expires_in]).to eq(3600)
                                                                                                        end
                                                                                                      end
                                                                                                  
                                                                                                      context '無効なリフレッシュトークンの場合' do
                                                                                                        before do
                                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                            .with(
                                                                                                              body: {
                                                                                                                refresh_token: invalid_refresh_token
                                                                                                              }
                                                                                                            )
                                                                                                            .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                        end
                                                                                                  
                                                                                                        it 'nilを返す' do
                                                                                                          expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                        end
                                                                                                      end
                                                                                                  
                                                                                                      context 'Supabase APIエラーの場合' do
                                                                                                        before do
                                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                            .to_return(status: 500)
                                                                                                        end
                                                                                                  
                                                                                                        it 'nilを返す' do
                                                                                                          expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                        end
                                                                                                      end
                                                                                                    
                                                                                                      describe '.generate_password_reset_link' do
                                                                                                        let(:valid_email) { 'user@example.com' }
                                                                                                        let(:invalid_email) { 'invalid' }
                                                                                                    
                                                                                                        context '有効なメールアドレスの場合' do
                                                                                                          before do
                                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                              .with(
                                                                                                                body: {
                                                                                                                  email: valid_email
                                                                                                                }
                                                                                                              )
                                                                                                              .to_return(status: 200, body: {}.to_json)
                                                                                                          end
                                                                                                    
                                                                                                          it 'trueを返す' do
                                                                                                            expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                                          end
                                                                                                        end
                                                                                                    
                                                                                                        context '無効なメールアドレスの場合' do
                                                                                                          before do
                                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                              .with(
                                                                                                                body: {
                                                                                                                  email: invalid_email
                                                                                                                }
                                                                                                              )
                                                                                                              .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                          end
                                                                                                    
                                                                                                          it 'falseを返す' do
                                                                                                            expect(described_class.generate_password_reset_link(invalid_email)).to be false
                                                                                                          end
                                                                                                        end
                                                                                                    
                                                                                                        context 'Supabase APIエラーの場合' do
                                                                                                          before do
                                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                              .to_return(status: 500)
                                                                                                          end
                                                                                                    
                                                                                                          it 'falseを返す' do
                                                                                                            expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                                          end
                                                                                                        end
                                                                                                      
                                                                                                        describe '.refresh_token' do
                                                                                                          let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                          let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                                                      
                                                                                                          context '有効なリフレッシュトークンの場合' do
                                                                                                            before do
                                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                .with(
                                                                                                                  body: {
                                                                                                                    refresh_token: valid_refresh_token
                                                                                                                  }
                                                                                                                )
                                                                                                                .to_return(
                                                                                                                  status: 200,
                                                                                                                  body: {
                                                                                                                    access_token: 'new_access_token',
                                                                                                                    refresh_token: 'new_refresh_token'
                                                                                                                  }.to_json
                                                                                                                )
                                                                                                            end
                                                                                                      
                                                                                                            it '新しいトークンペアを返す' do
                                                                                                              result = described_class.refresh_token(valid_refresh_token)
                                                                                                              expect(result).to eq({
                                                                                                                'access_token' => 'new_access_token',
                                                                                                                'refresh_token' => 'new_refresh_token'
                                                                                                              })
                                                                                                            end
                                                                                                          end
                                                                                                      
                                                                                                          context '無効なリフレッシュトークンの場合' do
                                                                                                            before do
                                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                .with(
                                                                                                                  body: {
                                                                                                                    refresh_token: invalid_refresh_token
                                                                                                                  }
                                                                                                                )
                                                                                                                .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                            end
                                                                                                      
                                                                                                            it 'nilを返す' do
                                                                                                              expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                            end
                                                                                                          end
                                                                                                      
                                                                                                          context 'Supabase APIエラーの場合' do
                                                                                                            before do
                                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                .to_return(status: 500)
                                                                                                            end
                                                                                                      
                                                                                                            it 'nilを返す' do
                                                                                                              expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                            end
                                                                                                          end
                                                                                                        
                                                                                                          describe '.generate_password_reset_link' do
                                                                                                            let(:valid_email) { 'user@example.com' }
                                                                                                            let(:invalid_email) { 'invalid' }
                                                                                                        
                                                                                                            context '有効なメールアドレスの場合' do
                                                                                                              before do
                                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                  .with(
                                                                                                                    body: {
                                                                                                                      email: valid_email
                                                                                                                    }
                                                                                                                  )
                                                                                                                  .to_return(status: 200, body: {}.to_json)
                                                                                                              end
                                                                                                        
                                                                                                              it 'trueを返す' do
                                                                                                                expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                                              end
                                                                                                            end
                                                                                                        
                                                                                                            context '無効なメールアドレスの場合' do
                                                                                                              before do
                                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                  .with(
                                                                                                                    body: {
                                                                                                                      email: invalid_email
                                                                                                                    }
                                                                                                                  )
                                                                                                                  .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                              end
                                                                                                        
                                                                                                              it 'falseを返す' do
                                                                                                                expect(described_class.generate_password_reset_link(invalid_email)).to be false
                                                                                                              end
                                                                                                            end
                                                                                                        
                                                                                                            context 'Supabase APIエラーの場合' do
                                                                                                              before do
                                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                  .to_return(status: 500)
                                                                                                              end
                                                                                                        
                                                                                                              it 'falseを返す' do
                                                                                                                expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                                              end
                                                                                                            end
                                                                                                          
                                                                                                            describe '.refresh_token' do
                                                                                                              let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                              let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                                                          
                                                                                                              context '有効なリフレッシュトークンの場合' do
                                                                                                                before do
                                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                    .with(
                                                                                                                      body: {
                                                                                                                        refresh_token: valid_refresh_token
                                                                                                                      }
                                                                                                                    )
                                                                                                                    .to_return(
                                                                                                                      status: 200,
                                                                                                                      body: {
                                                                                                                        access_token: 'new_access_token',
                                                                                                                        refresh_token: 'new_refresh_token',
                                                                                                                        expires_in: 3600
                                                                                                                      }.to_json
                                                                                                                    )
                                                                                                                end
                                                                                                          
                                                                                                                it '新しいトークン情報を返す' do
                                                                                                                  result = described_class.refresh_token(valid_refresh_token)
                                                                                                                  expect(result[:access_token]).to eq('new_access_token')
                                                                                                                  expect(result[:refresh_token]).to eq('new_refresh_token')
                                                                                                                  expect(result[:expires_in]).to eq(3600)
                                                                                                                end
                                                                                                              end
                                                                                                          
                                                                                                              context '無効なリフレッシュトークンの場合' do
                                                                                                                before do
                                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                    .with(
                                                                                                                      body: {
                                                                                                                        refresh_token: invalid_refresh_token
                                                                                                                      }
                                                                                                                    )
                                                                                                                    .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                                end
                                                                                                          
                                                                                                                it 'nilを返す' do
                                                                                                                  expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                                end
                                                                                                              end
                                                                                                          
                                                                                                              context 'Supabase APIエラーの場合' do
                                                                                                                before do
                                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                    .to_return(status: 500)
                                                                                                                end
                                                                                                          
                                                                                                                it 'nilを返す' do
                                                                                                                  expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                                end
                                                                                                              end
                                                                                                            
                                                                                                              describe '.generate_password_reset_link' do
                                                                                                                let(:valid_email) { 'user@example.com' }
                                                                                                                let(:invalid_email) { 'invalid' }
                                                                                                            
                                                                                                                context '有効なメールアドレスの場合' do
                                                                                                                  before do
                                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                      .with(
                                                                                                                        body: {
                                                                                                                          email: valid_email
                                                                                                                        }
                                                                                                                      )
                                                                                                                      .to_return(status: 200, body: {}.to_json)
                                                                                                                  end
                                                                                                            
                                                                                                                  it 'trueを返す' do
                                                                                                                    expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                                                  end
                                                                                                                end
                                                                                                            
                                                                                                                context '無効なメールアドレスの場合' do
                                                                                                                  before do
                                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                      .with(
                                                                                                                        body: {
                                                                                                                          email: invalid_email
                                                                                                                        }
                                                                                                                      )
                                                                                                                      .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                                  end
                                                                                                            
                                                                                                                  it 'falseを返す' do
                                                                                                                    expect(described_class.generate_password_reset_link(invalid_email)).to be false
                                                                                                                  end
                                                                                                                end
                                                                                                            
                                                                                                                context 'Supabase APIエラーの場合' do
                                                                                                                  before do
                                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                      .to_return(status: 500)
                                                                                                                  end
                                                                                                            
                                                                                                                  it 'falseを返す' do
                                                                                                                    expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                                                  end
                                                                                                                end
                                                                                                              
                                                                                                                describe '.refresh_token' do
                                                                                                                  let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                                  let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                                                              
                                                                                                                  context '有効なリフレッシュトークンの場合' do
                                                                                                                    before do
                                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                        .with(
                                                                                                                          body: {
                                                                                                                            refresh_token: valid_refresh_token
                                                                                                                          }
                                                                                                                        )
                                                                                                                        .to_return(
                                                                                                                          status: 200,
                                                                                                                          body: {
                                                                                                                            access_token: 'new_access_token',
                                                                                                                            refresh_token: 'new_refresh_token'
                                                                                                                          }.to_json
                                                                                                                        )
                                                                                                                    end
                                                                                                              
                                                                                                                    it '新しいトークンデータを返す' do
                                                                                                                      result = described_class.refresh_token(valid_refresh_token)
                                                                                                                      expect(result[:access_token]).to eq 'new_access_token'
                                                                                                                      expect(result[:refresh_token]).to eq 'new_refresh_token'
                                                                                                                    end
                                                                                                                  end
                                                                                                              
                                                                                                                  context '無効なリフレッシュトークンの場合' do
                                                                                                                    before do
                                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                        .with(
                                                                                                                          body: {
                                                                                                                            refresh_token: invalid_refresh_token
                                                                                                                          }
                                                                                                                        )
                                                                                                                        .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                                    end
                                                                                                              
                                                                                                                    it 'nilを返す' do
                                                                                                                      expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                                    end
                                                                                                                  end
                                                                                                              
                                                                                                                  context 'Supabase APIエラーの場合' do
                                                                                                                    before do
                                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                        .to_return(status: 500)
                                                                                                                    end
                                                                                                              
                                                                                                                    it 'nilを返す' do
                                                                                                                      expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                                    end
                                                                                                                  end
                                                                                                                
                                                                                                                  describe '.generate_password_reset_link' do
                                                                                                                    let(:valid_email) { 'user@example.com' }
                                                                                                                    let(:invalid_email) { 'invalid' }
                                                                                                                
                                                                                                                    context '有効なメールアドレスの場合' do
                                                                                                                      before do
                                                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                          .with(
                                                                                                                            body: {
                                                                                                                              email: valid_email
                                                                                                                            }
                                                                                                                          )
                                                                                                                          .to_return(status: 200, body: {}.to_json)
                                                                                                                      end
                                                                                                                
                                                                                                                      it 'trueを返す' do
                                                                                                                        expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                                                      end
                                                                                                                    end
                                                                                                                
                                                                                                                    context '無効なメールアドレスの場合' do
                                                                                                                      before do
                                                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                          .with(
                                                                                                                            body: {
                                                                                                                              email: invalid_email
                                                                                                                            }
                                                                                                                          )
                                                                                                                          .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                                      end
                                                                                                                
                                                                                                                      it 'falseを返す' do
                                                                                                                        expect(described_class.generate_password_reset_link(invalid_email)).to be false
                                                                                                                      end
                                                                                                                    end
                                                                                                                
                                                                                                                    context 'Supabase APIエラーの場合' do
                                                                                                                      before do
                                                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                          .to_return(status: 500)
                                                                                                                      end
                                                                                                                
                                                                                                                      it 'falseを返す' do
                                                                                                                        expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                                                      end
                                                                                                                    end
                                                                                                                  
                                                                                                                    describe '.refresh_token' do
                                                                                                                      let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                                      let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                                                                  
                                                                                                                      context '有効なリフレッシュトークンの場合' do
                                                                                                                        before do
                                                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                            .with(
                                                                                                                              body: {
                                                                                                                                refresh_token: valid_refresh_token
                                                                                                                              }
                                                                                                                            )
                                                                                                                            .to_return(
                                                                                                                              status: 200,
                                                                                                                              body: {
                                                                                                                                access_token: 'new_access_token',
                                                                                                                                refresh_token: 'new_refresh_token',
                                                                                                                                expires_in: 3600
                                                                                                                              }.to_json
                                                                                                                            )
                                                                                                                        end
                                                                                                                  
                                                                                                                        it '新しいトークン情報を返す' do
                                                                                                                          result = described_class.refresh_token(valid_refresh_token)
                                                                                                                          expect(result[:access_token]).to eq 'new_access_token'
                                                                                                                          expect(result[:refresh_token]).to eq 'new_refresh_token'
                                                                                                                          expect(result[:expires_in]).to eq 3600
                                                                                                                        end
                                                                                                                      end
                                                                                                                  
                                                                                                                      context '無効なリフレッシュトークンの場合' do
                                                                                                                        before do
                                                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                            .with(
                                                                                                                              body: {
                                                                                                                                refresh_token: invalid_refresh_token
                                                                                                                              }
                                                                                                                            )
                                                                                                                            .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                                        end
                                                                                                                  
                                                                                                                        it 'nilを返す' do
                                                                                                                          expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                                        end
                                                                                                                      end
                                                                                                                  
                                                                                                                      context 'Supabase APIエラーの場合' do
                                                                                                                        before do
                                                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                            .to_return(status: 500)
                                                                                                                        end
                                                                                                                  
                                                                                                                        it 'nilを返す' do
                                                                                                                          expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                                        end
                                                                                                                      end
                                                                                                                    
                                                                                                                      describe '.generate_password_reset_link' do
                                                                                                                        let(:valid_email) { 'user@example.com' }
                                                                                                                        let(:invalid_email) { 'invalid' }
                                                                                                                    
                                                                                                                        context '有効なメールアドレスの場合' do
                                                                                                                          before do
                                                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                              .with(
                                                                                                                                body: {
                                                                                                                                  email: valid_email
                                                                                                                                }
                                                                                                                              )
                                                                                                                              .to_return(status: 200, body: {}.to_json)
                                                                                                                          end
                                                                                                                    
                                                                                                                          it 'trueを返す' do
                                                                                                                            expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                                                          end
                                                                                                                        end
                                                                                                                    
                                                                                                                        context '無効なメールアドレスの場合' do
                                                                                                                          before do
                                                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                              .with(
                                                                                                                                body: {
                                                                                                                                  email: invalid_email
                                                                                                                                }
                                                                                                                              )
                                                                                                                              .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                                          end
                                                                                                                    
                                                                                                                          it 'falseを返す' do
                                                                                                                            expect(described_class.generate_password_reset_link(invalid_email)).to be false
                                                                                                                          end
                                                                                                                        end
                                                                                                                    
                                                                                                                        context 'Supabase APIエラーの場合' do
                                                                                                                          before do
                                                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                              .to_return(status: 500)
                                                                                                                          end
                                                                                                                    
                                                                                                                          it 'falseを返す' do
                                                                                                                            expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                                                          end
                                                                                                                        end
                                                                                                                      
                                                                                                                        describe '.refresh_token' do
                                                                                                                          let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                                          let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                                                                      
                                                                                                                          context '有効なリフレッシュトークンの場合' do
                                                                                                                            before do
                                                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                .with(
                                                                                                                                  body: {
                                                                                                                                    refresh_token: valid_refresh_token
                                                                                                                                  }
                                                                                                                                )
                                                                                                                                .to_return(
                                                                                                                                  status: 200,
                                                                                                                                  body: {
                                                                                                                                    access_token: 'new_access_token',
                                                                                                                                    refresh_token: 'new_refresh_token',
                                                                                                                                    expires_in: 3600
                                                                                                                                  }.to_json
                                                                                                                                )
                                                                                                                            end
                                                                                                                      
                                                                                                                            it '新しいトークン情報を返す' do
                                                                                                                              result = described_class.refresh_token(valid_refresh_token)
                                                                                                                              expect(result[:access_token]).to eq('new_access_token')
                                                                                                                              expect(result[:refresh_token]).to eq('new_refresh_token')
                                                                                                                              expect(result[:expires_in]).to eq(3600)
                                                                                                                            end
                                                                                                                          end
                                                                                                                      
                                                                                                                          context '無効なリフレッシュトークンの場合' do
                                                                                                                            before do
                                                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                .with(
                                                                                                                                  body: {
                                                                                                                                    refresh_token: invalid_refresh_token
                                                                                                                                  }
                                                                                                                                )
                                                                                                                                .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                                            end
                                                                                                                      
                                                                                                                            it 'nilを返す' do
                                                                                                                              expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                                            end
                                                                                                                          end
                                                                                                                      
                                                                                                                          context 'Supabase APIエラーの場合' do
                                                                                                                            before do
                                                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                .to_return(status: 500)
                                                                                                                            end
                                                                                                                      
                                                                                                                            it 'nilを返す' do
                                                                                                                              expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                                            end
                                                                                                                          end
                                                                                                                        
                                                                                                                          describe '.generate_password_reset_link' do
                                                                                                                            let(:valid_email) { 'user@example.com' }
                                                                                                                            let(:invalid_email) { 'invalid' }
                                                                                                                        
                                                                                                                            context '有効なメールアドレスの場合' do
                                                                                                                              before do
                                                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                  .with(
                                                                                                                                    body: {
                                                                                                                                      email: valid_email
                                                                                                                                    }
                                                                                                                                  )
                                                                                                                                  .to_return(status: 200, body: {}.to_json)
                                                                                                                              end
                                                                                                                        
                                                                                                                              it 'trueを返す' do
                                                                                                                                expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                                                              end
                                                                                                                            end
                                                                                                                        
                                                                                                                            context '無効なメールアドレスの場合' do
                                                                                                                              before do
                                                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                  .with(
                                                                                                                                    body: {
                                                                                                                                      email: invalid_email
                                                                                                                                    }
                                                                                                                                  )
                                                                                                                                  .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                                              end
                                                                                                                        
                                                                                                                              it 'falseを返す' do
                                                                                                                                expect(described_class.generate_password_reset_link(invalid_email)).to be false
                                                                                                                              end
                                                                                                                            end
                                                                                                                        
                                                                                                                            context 'Supabase APIエラーの場合' do
                                                                                                                              before do
                                                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                  .to_return(status: 500)
                                                                                                                              end
                                                                                                                        
                                                                                                                              it 'falseを返す' do
                                                                                                                                expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                                                              end
                                                                                                                            end
                                                                                                                          
                                                                                                                            describe '.refresh_token' do
                                                                                                                              let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                                              let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                                                                          
                                                                                                                              context '有効なリフレッシュトークンの場合' do
                                                                                                                                before do
                                                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                    .with(
                                                                                                                                      body: {
                                                                                                                                        refresh_token: valid_refresh_token
                                                                                                                                      }
                                                                                                                                    )
                                                                                                                                    .to_return(
                                                                                                                                      status: 200,
                                                                                                                                      body: {
                                                                                                                                        access_token: 'new_access_token',
                                                                                                                                        refresh_token: 'new_refresh_token',
                                                                                                                                        expires_in: 3600
                                                                                                                                      }.to_json
                                                                                                                                    )
                                                                                                                                end
                                                                                                                          
                                                                                                                                it '新しいトークン情報を返す' do
                                                                                                                                  result = described_class.refresh_token(valid_refresh_token)
                                                                                                                                  expect(result[:access_token]).to eq('new_access_token')
                                                                                                                                  expect(result[:refresh_token]).to eq('new_refresh_token')
                                                                                                                                  expect(result[:expires_in]).to eq(3600)
                                                                                                                                end
                                                                                                                              end
                                                                                                                          
                                                                                                                              context '無効なリフレッシュトークンの場合' do
                                                                                                                                before do
                                                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                    .with(
                                                                                                                                      body: {
                                                                                                                                        refresh_token: invalid_refresh_token
                                                                                                                                      }
                                                                                                                                    )
                                                                                                                                    .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                                                end
                                                                                                                          
                                                                                                                                it 'nilを返す' do
                                                                                                                                  expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                                                end
                                                                                                                              end
                                                                                                                          
                                                                                                                              context 'Supabase APIエラーの場合' do
                                                                                                                                before do
                                                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                    .to_return(status: 500)
                                                                                                                                end
                                                                                                                          
                                                                                                                                it 'nilを返す' do
                                                                                                                                  expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                                                end
                                                                                                                              end
                                                                                                                            
                                                                                                                              describe '.generate_password_reset_link' do
                                                                                                                                let(:valid_email) { 'user@example.com' }
                                                                                                                                let(:invalid_email) { 'invalid' }
                                                                                                                            
                                                                                                                                context '有効なメールアドレスの場合' do
                                                                                                                                  before do
                                                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                      .with(
                                                                                                                                        body: {
                                                                                                                                          email: valid_email
                                                                                                                                        }
                                                                                                                                      )
                                                                                                                                      .to_return(status: 200, body: {}.to_json)
                                                                                                                                  end
                                                                                                                            
                                                                                                                                  it 'trueを返す' do
                                                                                                                                    expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                                                                  end
                                                                                                                                end
                                                                                                                            
                                                                                                                                context '無効なメールアドレスの場合' do
                                                                                                                                  before do
                                                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                      .with(
                                                                                                                                        body: {
                                                                                                                                          email: invalid_email
                                                                                                                                        }
                                                                                                                                      )
                                                                                                                                      .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                                                  end
                                                                                                                            
                                                                                                                                  it 'falseを返す' do
                                                                                                                                    expect(described_class.generate_password_reset_link(invalid_email)).to be false
                                                                                                                                  end
                                                                                                                                end
                                                                                                                            
                                                                                                                                context 'Supabase APIエラーの場合' do
                                                                                                                                  before do
                                                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                      .to_return(status: 500)
                                                                                                                                  end
                                                                                                                            
                                                                                                                                  it 'falseを返す' do
                                                                                                                                    expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                                                                  end
                                                                                                                                end
                                                                                                                              
                                                                                                                                describe '.refresh_token' do
                                                                                                                                  let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                                                  let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                                                                              
                                                                                                                                  context '有効なリフレッシュトークンの場合' do
                                                                                                                                    before do
                                                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                        .with(
                                                                                                                                          body: {
                                                                                                                                            refresh_token: valid_refresh_token
                                                                                                                                          }
                                                                                                                                        )
                                                                                                                                        .to_return(
                                                                                                                                          status: 200,
                                                                                                                                          body: {
                                                                                                                                            access_token: 'new_access_token',
                                                                                                                                            refresh_token: 'new_refresh_token',
                                                                                                                                            expires_in: 3600
                                                                                                                                          }.to_json
                                                                                                                                        )
                                                                                                                                    end
                                                                                                                              
                                                                                                                                    it '新しいトークン情報を返す' do
                                                                                                                                      result = described_class.refresh_token(valid_refresh_token)
                                                                                                                                      expect(result).to eq({
                                                                                                                                        'access_token' => 'new_access_token',
                                                                                                                                        'refresh_token' => 'new_refresh_token',
                                                                                                                                        'expires_in' => 3600
                                                                                                                                      })
                                                                                                                                    end
                                                                                                                                  end
                                                                                                                              
                                                                                                                                  context '無効なリフレッシュトークンの場合' do
                                                                                                                                    before do
                                                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                        .with(
                                                                                                                                          body: {
                                                                                                                                            refresh_token: invalid_refresh_token
                                                                                                                                          }
                                                                                                                                        )
                                                                                                                                        .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                                                    end
                                                                                                                              
                                                                                                                                    it 'nilを返す' do
                                                                                                                                      expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                                                    end
                                                                                                                                  end
                                                                                                                              
                                                                                                                                  context 'Supabase APIエラーの場合' do
                                                                                                                                    before do
                                                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                        .to_return(status: 500)
                                                                                                                                    end
                                                                                                                              
                                                                                                                                    it 'nilを返す' do
                                                                                                                                      expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                                                    end
                                                                                                                                  end
                                                                                                                                
                                                                                                                                  describe '.generate_password_reset_link' do
                                                                                                                                    let(:valid_email) { 'user@example.com' }
                                                                                                                                    let(:invalid_email) { 'invalid@example.com' }
                                                                                                                                
                                                                                                                                    context '有効なメールアドレスの場合' do
                                                                                                                                      before do
                                                                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                          .with(
                                                                                                                                            body: {
                                                                                                                                              email: valid_email
                                                                                                                                            }
                                                                                                                                          )
                                                                                                                                          .to_return(
                                                                                                                                            status: 200,
                                                                                                                                            body: {
                                                                                                                                              message: 'Password recovery email sent'
                                                                                                                                            }.to_json
                                                                                                                                          )
                                                                                                                                      end
                                                                                                                                
                                                                                                                                      it 'trueを返す' do
                                                                                                                                        expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                                                                      end
                                                                                                                                    end
                                                                                                                                
                                                                                                                                    context '無効なメールアドレスの場合' do
                                                                                                                                      before do
                                                                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                          .with(
                                                                                                                                            body: {
                                                                                                                                              email: invalid_email
                                                                                                                                            }
                                                                                                                                          )
                                                                                                                                          .to_return(status: 404, body: { error: 'User not found' }.to_json)
                                                                                                                                      end
                                                                                                                                
                                                                                                                                      it 'falseを返す' do
                                                                                                                                        expect(described_class.generate_password_reset_link(invalid_email)).to be false
                                                                                                                                      end
                                                                                                                                    end
                                                                                                                                
                                                                                                                                    context 'Supabase APIエラーの場合' do
                                                                                                                                      before do
                                                                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                          .to_return(status: 500)
                                                                                                                                      end
                                                                                                                                
                                                                                                                                      it 'falseを返す' do
                                                                                                                                        expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                                                                      end
                                                                                                                                    end
                                                                                                                                  
                                                                                                                                    describe '.refresh_token' do
                                                                                                                                      let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                                                      let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                                                                                      let(:success_response) do
                                                                                                                                        {
                                                                                                                                          access_token: 'new_access_token',
                                                                                                                                          refresh_token: 'new_refresh_token',
                                                                                                                                          expires_in: 3600
                                                                                                                                        }
                                                                                                                                      end
                                                                                                                                  
                                                                                                                                      context '有効なリフレッシュトークンの場合' do
                                                                                                                                        before do
                                                                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                            .with(
                                                                                                                                              body: {
                                                                                                                                                refresh_token: valid_refresh_token
                                                                                                                                              }
                                                                                                                                            )
                                                                                                                                            .to_return(
                                                                                                                                              status: 200,
                                                                                                                                              body: success_response.to_json
                                                                                                                                            )
                                                                                                                                        end
                                                                                                                                  
                                                                                                                                        it '新しいトークン情報を返す' do
                                                                                                                                          result = described_class.refresh_token(valid_refresh_token)
                                                                                                                                          expect(result[:access_token]).to eq('new_access_token')
                                                                                                                                          expect(result[:refresh_token]).to eq('new_refresh_token')
                                                                                                                                          expect(result[:expires_in]).to eq(3600)
                                                                                                                                        end
                                                                                                                                      end
                                                                                                                                  
                                                                                                                                      context '無効なリフレッシュトークンの場合' do
                                                                                                                                        before do
                                                                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                            .with(
                                                                                                                                              body: {
                                                                                                                                                refresh_token: invalid_refresh_token
                                                                                                                                              }
                                                                                                                                            )
                                                                                                                                            .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                                                        end
                                                                                                                                  
                                                                                                                                        it 'nilを返す' do
                                                                                                                                          expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                                                        end
                                                                                                                                      end
                                                                                                                                  
                                                                                                                                      context 'Supabase APIエラーの場合' do
                                                                                                                                        before do
                                                                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                            .to_return(status: 500)
                                                                                                                                        end
                                                                                                                                  
                                                                                                                                        it 'nilを返す' do
                                                                                                                                          expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                                                        end
                                                                                                                                      end
                                                                                                                                    
                                                                                                                                      describe '.generate_password_reset_link' do
                                                                                                                                        let(:valid_email) { 'user@example.com' }
                                                                                                                                        let(:invalid_email) { 'invalid' }
                                                                                                                                        let(:success_response) { { message: 'Password reset link sent' } }
                                                                                                                                    
                                                                                                                                        context '有効なメールアドレスの場合' do
                                                                                                                                          before do
                                                                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                              .with(
                                                                                                                                                body: {
                                                                                                                                                  email: valid_email
                                                                                                                                                }
                                                                                                                                              )
                                                                                                                                              .to_return(
                                                                                                                                                status: 200,
                                                                                                                                                body: success_response.to_json
                                                                                                                                              )
                                                                                                                                          end
                                                                                                                                    
                                                                                                                                          it '成功レスポンスを返す' do
                                                                                                                                            result = described_class.generate_password_reset_link(valid_email)
                                                                                                                                            expect(result[:message]).to eq('Password reset link sent')
                                                                                                                                          end
                                                                                                                                        end
                                                                                                                                    
                                                                                                                                        context '無効なメールアドレスの場合' do
                                                                                                                                          before do
                                                                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                              .with(
                                                                                                                                                body: {
                                                                                                                                                  email: invalid_email
                                                                                                                                                }
                                                                                                                                              )
                                                                                                                                              .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                                                          end
                                                                                                                                    
                                                                                                                                          it 'nilを返す' do
                                                                                                                                            expect(described_class.generate_password_reset_link(invalid_email)).to be_nil
                                                                                                                                          end
                                                                                                                                        end
                                                                                                                                    
                                                                                                                                        context 'Supabase APIエラーの場合' do
                                                                                                                                          before do
                                                                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                              .to_return(status: 500)
                                                                                                                                          end
                                                                                                                                    
                                                                                                                                          it 'nilを返す' do
                                                                                                                                            expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                                                                                                                          end
                                                                                                                                        end
                                                                                                                                      
                                                                                                                                        describe '.refresh_token' do
                                                                                                                                          let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                                                          let(:invalid_refresh_token) { 'invalid' }
                                                                                                                                          let(:success_response) do
                                                                                                                                            {
                                                                                                                                              access_token: 'new_access_token',
                                                                                                                                              refresh_token: 'new_refresh_token',
                                                                                                                                              expires_in: 3600
                                                                                                                                            }
                                                                                                                                          end
                                                                                                                                      
                                                                                                                                          context '有効なリフレッシュトークンの場合' do
                                                                                                                                            before do
                                                                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                .with(
                                                                                                                                                  body: {
                                                                                                                                                    grant_type: 'refresh_token',
                                                                                                                                                    refresh_token: valid_refresh_token
                                                                                                                                                  }
                                                                                                                                                )
                                                                                                                                                .to_return(
                                                                                                                                                  status: 200,
                                                                                                                                                  body: success_response.to_json
                                                                                                                                                )
                                                                                                                                            end
                                                                                                                                      
                                                                                                                                            it '新しいトークン情報を返す' do
                                                                                                                                              result = described_class.refresh_token(valid_refresh_token)
                                                                                                                                              expect(result[:access_token]).to eq('new_access_token')
                                                                                                                                              expect(result[:refresh_token]).to eq('new_refresh_token')
                                                                                                                                              expect(result[:expires_in]).to eq(3600)
                                                                                                                                            end
                                                                                                                                          end
                                                                                                                                      
                                                                                                                                          context '無効なリフレッシュトークンの場合' do
                                                                                                                                            before do
                                                                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                .with(
                                                                                                                                                  body: {
                                                                                                                                                    grant_type: 'refresh_token',
                                                                                                                                                    refresh_token: invalid_refresh_token
                                                                                                                                                  }
                                                                                                                                                )
                                                                                                                                                .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                                                            end
                                                                                                                                      
                                                                                                                                            it 'nilを返す' do
                                                                                                                                              expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                                                            end
                                                                                                                                          end
                                                                                                                                      
                                                                                                                                          context 'Supabase APIエラーの場合' do
                                                                                                                                            before do
                                                                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                .to_return(status: 500)
                                                                                                                                            end
                                                                                                                                      
                                                                                                                                            it 'nilを返す' do
                                                                                                                                              expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                                                            end
                                                                                                                                          end
                                                                                                                                        
                                                                                                                                          describe '.generate_password_reset_link' do
                                                                                                                                            let(:valid_email) { 'user@example.com' }
                                                                                                                                            let(:invalid_email) { 'invalid' }
                                                                                                                                            let(:success_response) { { message: 'Password reset link sent' } }
                                                                                                                                        
                                                                                                                                            context '有効なメールアドレスの場合' do
                                                                                                                                              before do
                                                                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                  .with(
                                                                                                                                                    body: {
                                                                                                                                                      email: valid_email,
                                                                                                                                                      redirect_to: "#{ENV['FRONTEND_URL']}/auth/reset-password"
                                                                                                                                                    }
                                                                                                                                                  )
                                                                                                                                                  .to_return(
                                                                                                                                                    status: 200,
                                                                                                                                                    body: success_response.to_json
                                                                                                                                                  )
                                                                                                                                              end
                                                                                                                                        
                                                                                                                                              it '成功レスポンスを返す' do
                                                                                                                                                result = described_class.generate_password_reset_link(valid_email)
                                                                                                                                                expect(result[:message]).to eq('Password reset link sent')
                                                                                                                                              end
                                                                                                                                            end
                                                                                                                                        
                                                                                                                                            context '無効なメールアドレスの場合' do
                                                                                                                                              before do
                                                                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                  .with(
                                                                                                                                                    body: {
                                                                                                                                                      email: invalid_email,
                                                                                                                                                      redirect_to: "#{ENV['FRONTEND_URL']}/auth/reset-password"
                                                                                                                                                    }
                                                                                                                                                  )
                                                                                                                                                  .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                                                              end
                                                                                                                                        
                                                                                                                                              it 'nilを返す' do
                                                                                                                                                expect(described_class.generate_password_reset_link(invalid_email)).to be_nil
                                                                                                                                              end
                                                                                                                                            end
                                                                                                                                        
                                                                                                                                            context 'Supabase APIエラーの場合' do
                                                                                                                                              before do
                                                                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                  .to_return(status: 500)
                                                                                                                                              end
                                                                                                                                        
                                                                                                                                              it 'nilを返す' do
                                                                                                                                                expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                                                                                                                              end
                                                                                                                                            end
                                                                                                                                          
                                                                                                                                            describe '.refresh_token' do
                                                                                                                                              let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                                                              let(:invalid_refresh_token) { 'invalid_refresh_token' }
                                                                                                                                              let(:success_response) do
                                                                                                                                                {
                                                                                                                                                  access_token: 'new_access_token',
                                                                                                                                                  refresh_token: 'new_refresh_token',
                                                                                                                                                  expires_in: 3600
                                                                                                                                                }
                                                                                                                                              end
                                                                                                                                          
                                                                                                                                              context '有効なリフレッシュトークンの場合' do
                                                                                                                                                before do
                                                                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                                    .with(
                                                                                                                                                      body: { refresh_token: valid_refresh_token },
                                                                                                                                                      headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                    )
                                                                                                                                                    .to_return(
                                                                                                                                                      status: 200,
                                                                                                                                                      body: success_response.to_json
                                                                                                                                                    )
                                                                                                                                                end
                                                                                                                                          
                                                                                                                                                it '新しいトークン情報を返す' do
                                                                                                                                                  result = described_class.refresh_token(valid_refresh_token)
                                                                                                                                                  expect(result[:access_token]).to eq('new_access_token')
                                                                                                                                                  expect(result[:refresh_token]).to eq('new_refresh_token')
                                                                                                                                                  expect(result[:expires_in]).to eq(3600)
                                                                                                                                                end
                                                                                                                                              end
                                                                                                                                          
                                                                                                                                              context '無効なリフレッシュトークンの場合' do
                                                                                                                                                before do
                                                                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                                    .with(
                                                                                                                                                      body: { refresh_token: invalid_refresh_token },
                                                                                                                                                      headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                    )
                                                                                                                                                    .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                                                                end
                                                                                                                                          
                                                                                                                                                it 'nilを返す' do
                                                                                                                                                  expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                                                                end
                                                                                                                                              end
                                                                                                                                          
                                                                                                                                              context 'Supabase APIエラーの場合' do
                                                                                                                                                before do
                                                                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
                                                                                                                                                    .to_return(status: 500)
                                                                                                                                                end
                                                                                                                                          
                                                                                                                                                it 'nilを返す' do
                                                                                                                                                  expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                                                                end
                                                                                                                                              end
                                                                                                                                            
                                                                                                                                              describe '.generate_password_reset_link' do
                                                                                                                                                let(:valid_email) { 'user@example.com' }
                                                                                                                                                let(:invalid_email) { 'invalid' }
                                                                                                                                                let(:success_response) { { message: 'Password reset email sent' } }
                                                                                                                                            
                                                                                                                                                context '有効なメールアドレスの場合' do
                                                                                                                                                  before do
                                                                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                      .with(
                                                                                                                                                        body: { email: valid_email },
                                                                                                                                                        headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                      )
                                                                                                                                                      .to_return(status: 200, body: success_response.to_json)
                                                                                                                                                  end
                                                                                                                                            
                                                                                                                                                  it 'trueを返す' do
                                                                                                                                                    expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                                                                                  end
                                                                                                                                                end
                                                                                                                                            
                                                                                                                                                context '無効なメールアドレスの場合' do
                                                                                                                                                  before do
                                                                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                      .with(
                                                                                                                                                        body: { email: invalid_email },
                                                                                                                                                        headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                      )
                                                                                                                                                      .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                                                                  end
                                                                                                                                            
                                                                                                                                                  it 'falseを返す' do
                                                                                                                                                    expect(described_class.generate_password_reset_link(invalid_email)).to be false
                                                                                                                                                  end
                                                                                                                                                end
                                                                                                                                            
                                                                                                                                                context 'Supabase APIエラーの場合' do
                                                                                                                                                  before do
                                                                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                      .to_return(status: 500)
                                                                                                                                                  end
                                                                                                                                            
                                                                                                                                                  it 'falseを返す' do
                                                                                                                                                    expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                                                                                  end
                                                                                                                                                end
                                                                                                                                              
                                                                                                                                                describe '.refresh_token' do
                                                                                                                                                  let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                                                                  let(:invalid_refresh_token) { 'invalid' }
                                                                                                                                                  let(:success_response) do
                                                                                                                                                    {
                                                                                                                                                      access_token: 'new_access_token',
                                                                                                                                                      refresh_token: 'new_refresh_token',
                                                                                                                                                      expires_in: 3600
                                                                                                                                                    }
                                                                                                                                                  end
                                                                                                                                              
                                                                                                                                                  context '有効なリフレッシュトークンの場合' do
                                                                                                                                                    before do
                                                                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                        .with(
                                                                                                                                                          body: {
                                                                                                                                                            grant_type: 'refresh_token',
                                                                                                                                                            refresh_token: valid_refresh_token
                                                                                                                                                          },
                                                                                                                                                          headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                        )
                                                                                                                                                        .to_return(status: 200, body: success_response.to_json)
                                                                                                                                                    end
                                                                                                                                              
                                                                                                                                                    it '新しいトークンデータを返す' do
                                                                                                                                                      result = described_class.refresh_token(valid_refresh_token)
                                                                                                                                                      expect(result[:access_token]).to eq('new_access_token')
                                                                                                                                                      expect(result[:refresh_token]).to eq('new_refresh_token')
                                                                                                                                                      expect(result[:expires_in]).to eq(3600)
                                                                                                                                                    end
                                                                                                                                                  end
                                                                                                                                              
                                                                                                                                                  context '無効なリフレッシュトークンの場合' do
                                                                                                                                                    before do
                                                                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                        .with(
                                                                                                                                                          body: {
                                                                                                                                                            grant_type: 'refresh_token',
                                                                                                                                                            refresh_token: invalid_refresh_token
                                                                                                                                                          },
                                                                                                                                                          headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                        )
                                                                                                                                                        .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                                                                    end
                                                                                                                                              
                                                                                                                                                    it 'nilを返す' do
                                                                                                                                                      expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                                                                    end
                                                                                                                                                  end
                                                                                                                                              
                                                                                                                                                  context 'Supabase APIエラーの場合' do
                                                                                                                                                    before do
                                                                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                        .to_return(status: 500)
                                                                                                                                                    end
                                                                                                                                              
                                                                                                                                                    it 'nilを返す' do
                                                                                                                                                      expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                                                                    end
                                                                                                                                                  end
                                                                                                                                                
                                                                                                                                                  describe '.generate_password_reset_link' do
                                                                                                                                                    let(:valid_email) { 'user@example.com' }
                                                                                                                                                    let(:invalid_email) { 'invalid' }
                                                                                                                                                    let(:success_response) { { message: 'Password reset email sent' } }
                                                                                                                                                
                                                                                                                                                    context '有効なメールアドレスの場合' do
                                                                                                                                                      before do
                                                                                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                          .with(
                                                                                                                                                            body: { email: valid_email },
                                                                                                                                                            headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                          )
                                                                                                                                                          .to_return(status: 200, body: success_response.to_json)
                                                                                                                                                      end
                                                                                                                                                
                                                                                                                                                      it 'trueを返す' do
                                                                                                                                                        expect(described_class.generate_password_reset_link(valid_email)).to be true
                                                                                                                                                      end
                                                                                                                                                    end
                                                                                                                                                
                                                                                                                                                    context '無効なメールアドレスの場合' do
                                                                                                                                                      before do
                                                                                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                          .with(
                                                                                                                                                            body: { email: invalid_email },
                                                                                                                                                            headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                          )
                                                                                                                                                          .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                                                                      end
                                                                                                                                                
                                                                                                                                                      it 'falseを返す' do
                                                                                                                                                        expect(described_class.generate_password_reset_link(invalid_email)).to be false
                                                                                                                                                      end
                                                                                                                                                    end
                                                                                                                                                
                                                                                                                                                    context 'Supabase APIエラーの場合' do
                                                                                                                                                      before do
                                                                                                                                                        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                          .to_return(status: 500)
                                                                                                                                                      end
                                                                                                                                                
                                                                                                                                                      it 'falseを返す' do
                                                                                                                                                        expect(described_class.generate_password_reset_link(valid_email)).to be false
                                                                                                                                                      end
                                                                                                                                                    end
                                                                                                                                                  
                                                                                                                                                    describe '.refresh_token' do
                                                                                                                                                      let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                                                                      let(:invalid_refresh_token) { 'invalid' }
                                                                                                                                                      let(:success_response) {
                                                                                                                                                        {
                                                                                                                                                          access_token: 'new_access_token',
                                                                                                                                                          refresh_token: 'new_refresh_token',
                                                                                                                                                          expires_in: 3600
                                                                                                                                                        }
                                                                                                                                                      }
                                                                                                                                                  
                                                                                                                                                      context '有効なリフレッシュトークンの場合' do
                                                                                                                                                        before do
                                                                                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                            .with(
                                                                                                                                                              body: {
                                                                                                                                                                grant_type: 'refresh_token',
                                                                                                                                                                refresh_token: valid_refresh_token
                                                                                                                                                              },
                                                                                                                                                              headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                            )
                                                                                                                                                            .to_return(status: 200, body: success_response.to_json)
                                                                                                                                                        end
                                                                                                                                                  
                                                                                                                                                        it '新しいトークンデータを返す' do
                                                                                                                                                          result = described_class.refresh_token(valid_refresh_token)
                                                                                                                                                          expect(result[:access_token]).to eq('new_access_token')
                                                                                                                                                          expect(result[:refresh_token]).to eq('new_refresh_token')
                                                                                                                                                          expect(result[:expires_in]).to eq(3600)
                                                                                                                                                        end
                                                                                                                                                      end
                                                                                                                                                  
                                                                                                                                                      context '無効なリフレッシュトークンの場合' do
                                                                                                                                                        before do
                                                                                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                            .with(
                                                                                                                                                              body: {
                                                                                                                                                                grant_type: 'refresh_token',
                                                                                                                                                                refresh_token: invalid_refresh_token
                                                                                                                                                              },
                                                                                                                                                              headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                            )
                                                                                                                                                            .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                                                                        end
                                                                                                                                                  
                                                                                                                                                        it 'nilを返す' do
                                                                                                                                                          expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                                                                        end
                                                                                                                                                      end
                                                                                                                                                  
                                                                                                                                                      context 'Supabase APIエラーの場合' do
                                                                                                                                                        before do
                                                                                                                                                          stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                            .to_return(status: 500)
                                                                                                                                                        end
                                                                                                                                                  
                                                                                                                                                        it 'nilを返す' do
                                                                                                                                                          expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                                                                        end
                                                                                                                                                      end
                                                                                                                                                    
                                                                                                                                                      describe '.generate_password_reset_link' do
                                                                                                                                                        let(:valid_email) { 'user@example.com' }
                                                                                                                                                        let(:invalid_email) { 'invalid' }
                                                                                                                                                        let(:success_response) { { message: 'Password reset link sent' } }
                                                                                                                                                    
                                                                                                                                                        context '有効なメールアドレスの場合' do
                                                                                                                                                          before do
                                                                                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                              .with(
                                                                                                                                                                body: { email: valid_email },
                                                                                                                                                                headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                              )
                                                                                                                                                              .to_return(status: 200, body: success_response.to_json)
                                                                                                                                                          end
                                                                                                                                                    
                                                                                                                                                          it '成功レスポンスを返す' do
                                                                                                                                                            result = described_class.generate_password_reset_link(valid_email)
                                                                                                                                                            expect(result[:message]).to eq('Password reset link sent')
                                                                                                                                                          end
                                                                                                                                                        end
                                                                                                                                                    
                                                                                                                                                        context '無効なメールアドレスの場合' do
                                                                                                                                                          before do
                                                                                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                              .with(
                                                                                                                                                                body: { email: invalid_email },
                                                                                                                                                                headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                              )
                                                                                                                                                              .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                                                                          end
                                                                                                                                                    
                                                                                                                                                          it 'nilを返す' do
                                                                                                                                                            expect(described_class.generate_password_reset_link(invalid_email)).to be_nil
                                                                                                                                                          end
                                                                                                                                                        end
                                                                                                                                                    
                                                                                                                                                        context 'Supabase APIエラーの場合' do
                                                                                                                                                          before do
                                                                                                                                                            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                              .to_return(status: 500)
                                                                                                                                                          end
                                                                                                                                                    
                                                                                                                                                          it 'nilを返す' do
                                                                                                                                                            expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                                                                                                                                          end
                                                                                                                                                        end
                                                                                                                                                      
                                                                                                                                                        describe '.refresh_token' do
                                                                                                                                                          let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                                                                          let(:invalid_refresh_token) { 'invalid' }
                                                                                                                                                          let(:success_response) {
                                                                                                                                                            {
                                                                                                                                                              access_token: 'new_access_token',
                                                                                                                                                              refresh_token: 'new_refresh_token',
                                                                                                                                                              expires_in: 3600
                                                                                                                                                            }
                                                                                                                                                          }
                                                                                                                                                      
                                                                                                                                                          context '有効なリフレッシュトークンの場合' do
                                                                                                                                                            before do
                                                                                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                                .with(
                                                                                                                                                                  body: {
                                                                                                                                                                    grant_type: 'refresh_token',
                                                                                                                                                                    refresh_token: valid_refresh_token
                                                                                                                                                                  },
                                                                                                                                                                  headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                                )
                                                                                                                                                                .to_return(status: 200, body: success_response.to_json)
                                                                                                                                                            end
                                                                                                                                                      
                                                                                                                                                            it '新しいトークン情報を返す' do
                                                                                                                                                              result = described_class.refresh_token(valid_refresh_token)
                                                                                                                                                              expect(result[:access_token]).to eq('new_access_token')
                                                                                                                                                              expect(result[:refresh_token]).to eq('new_refresh_token')
                                                                                                                                                              expect(result[:expires_in]).to eq(3600)
                                                                                                                                                            end
                                                                                                                                                          end
                                                                                                                                                      
                                                                                                                                                          context '無効なリフレッシュトークンの場合' do
                                                                                                                                                            before do
                                                                                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                                .with(
                                                                                                                                                                  body: {
                                                                                                                                                                    grant_type: 'refresh_token',
                                                                                                                                                                    refresh_token: invalid_refresh_token
                                                                                                                                                                  },
                                                                                                                                                                  headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                                )
                                                                                                                                                                .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                                                                            end
                                                                                                                                                      
                                                                                                                                                            it 'nilを返す' do
                                                                                                                                                              expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                                                                            end
                                                                                                                                                          end
                                                                                                                                                      
                                                                                                                                                          context 'Supabase APIエラーの場合' do
                                                                                                                                                            before do
                                                                                                                                                              stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                                .to_return(status: 500)
                                                                                                                                                            end
                                                                                                                                                      
                                                                                                                                                            it 'nilを返す' do
                                                                                                                                                              expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                                                                            end
                                                                                                                                                          end
                                                                                                                                                        
                                                                                                                                                          describe '.generate_password_reset_link' do
                                                                                                                                                            let(:valid_email) { 'user@example.com' }
                                                                                                                                                            let(:invalid_email) { 'invalid' }
                                                                                                                                                            let(:success_response) {
                                                                                                                                                              {
                                                                                                                                                                data: {
                                                                                                                                                                  action_link: 'https://example.com/reset-password?token=abc123'
                                                                                                                                                                }
                                                                                                                                                              }
                                                                                                                                                            }
                                                                                                                                                        
                                                                                                                                                            context '有効なメールアドレスの場合' do
                                                                                                                                                              before do
                                                                                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                                  .with(
                                                                                                                                                                    body: { email: valid_email },
                                                                                                                                                                    headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                                  )
                                                                                                                                                                  .to_return(status: 200, body: success_response.to_json)
                                                                                                                                                              end
                                                                                                                                                        
                                                                                                                                                              it 'パスワードリセットリンクを返す' do
                                                                                                                                                                result = described_class.generate_password_reset_link(valid_email)
                                                                                                                                                                expect(result[:action_link]).to eq('https://example.com/reset-password?token=abc123')
                                                                                                                                                              end
                                                                                                                                                            end
                                                                                                                                                        
                                                                                                                                                            context '無効なメールアドレスの場合' do
                                                                                                                                                              before do
                                                                                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                                  .with(
                                                                                                                                                                    body: { email: invalid_email },
                                                                                                                                                                    headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                                  )
                                                                                                                                                                  .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                                                                              end
                                                                                                                                                        
                                                                                                                                                              it 'nilを返す' do
                                                                                                                                                                expect(described_class.generate_password_reset_link(invalid_email)).to be_nil
                                                                                                                                                              end
                                                                                                                                                            end
                                                                                                                                                        
                                                                                                                                                            context 'Supabase APIエラーの場合' do
                                                                                                                                                              before do
                                                                                                                                                                stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                                  .to_return(status: 500)
                                                                                                                                                              end
                                                                                                                                                        
                                                                                                                                                              it 'nilを返す' do
                                                                                                                                                                expect(described_class.generate_password_reset_link(valid_email)).to be_nil
                                                                                                                                                              end
                                                                                                                                                            end
                                                                                                                                                          
                                                                                                                                                            describe '.refresh_token' do
                                                                                                                                                              let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                                                                              let(:invalid_refresh_token) { 'invalid' }
                                                                                                                                                              let(:success_response) {
                                                                                                                                                                {
                                                                                                                                                                  access_token: 'new_access_token',
                                                                                                                                                                  refresh_token: 'new_refresh_token',
                                                                                                                                                                  expires_in: 3600
                                                                                                                                                                }
                                                                                                                                                              }
                                                                                                                                                          
                                                                                                                                                              context '有効なリフレッシュトークンの場合' do
                                                                                                                                                                before do
                                                                                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                                    .with(
                                                                                                                                                                      body: {
                                                                                                                                                                        grant_type: 'refresh_token',
                                                                                                                                                                        refresh_token: valid_refresh_token
                                                                                                                                                                      },
                                                                                                                                                                      headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                                    )
                                                                                                                                                                    .to_return(status: 200, body: success_response.to_json)
                                                                                                                                                                end
                                                                                                                                                          
                                                                                                                                                                it '新しいトークン情報を返す' do
                                                                                                                                                                  result = described_class.refresh_token(valid_refresh_token)
                                                                                                                                                                  expect(result[:access_token]).to eq('new_access_token')
                                                                                                                                                                  expect(result[:refresh_token]).to eq('new_refresh_token')
                                                                                                                                                                  expect(result[:expires_in]).to eq(3600)
                                                                                                                                                                end
                                                                                                                                                              end
                                                                                                                                                          
                                                                                                                                                              context '無効なリフレッシュトークンの場合' do
                                                                                                                                                                before do
                                                                                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                                    .with(
                                                                                                                                                                      body: {
                                                                                                                                                                        grant_type: 'refresh_token',
                                                                                                                                                                        refresh_token: invalid_refresh_token
                                                                                                                                                                      },
                                                                                                                                                                      headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                                    )
                                                                                                                                                                    .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                                                                                end
                                                                                                                                                          
                                                                                                                                                                it 'nilを返す' do
                                                                                                                                                                  expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                                                                                end
                                                                                                                                                              end
                                                                                                                                                          
                                                                                                                                                              context 'Supabase APIエラーの場合' do
                                                                                                                                                                before do
                                                                                                                                                                  stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                                    .to_return(status: 500)
                                                                                                                                                                end
                                                                                                                                                          
                                                                                                                                                                it 'nilを返す' do
                                                                                                                                                                  expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                                                                                end
                                                                                                                                                              end
                                                                                                                                                            
                                                                                                                                                              describe '.generate_password_reset_link' do
                                                                                                                                                                let(:valid_email) { 'user@example.com' }
                                                                                                                                                                let(:invalid_email) { 'invalid' }
                                                                                                                                                                let(:success_response) { { message: 'Password reset link sent' } }
                                                                                                                                                            
                                                                                                                                                                context '有効なメールアドレスの場合' do
                                                                                                                                                                  before do
                                                                                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                                      .with(
                                                                                                                                                                        body: { email: valid_email },
                                                                                                                                                                        headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                                      )
                                                                                                                                                                      .to_return(status: 200, body: success_response.to_json)
                                                                                                                                                                  end
                                                                                                                                                            
                                                                                                                                                                  it 'trueを返す' do
                                                                                                                                                                    expect(described_class.generate_password_reset_link(valid_email)).to be_truthy
                                                                                                                                                                  end
                                                                                                                                                                end
                                                                                                                                                            
                                                                                                                                                                context '無効なメールアドレスの場合' do
                                                                                                                                                                  before do
                                                                                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                                      .with(
                                                                                                                                                                        body: { email: invalid_email },
                                                                                                                                                                        headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                                      )
                                                                                                                                                                      .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
                                                                                                                                                                  end
                                                                                                                                                            
                                                                                                                                                                  it 'falseを返す' do
                                                                                                                                                                    expect(described_class.generate_password_reset_link(invalid_email)).to be_falsey
                                                                                                                                                                  end
                                                                                                                                                                end
                                                                                                                                                            
                                                                                                                                                                context 'Supabase APIエラーの場合' do
                                                                                                                                                                  before do
                                                                                                                                                                    stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
                                                                                                                                                                      .to_return(status: 500)
                                                                                                                                                                  end
                                                                                                                                                            
                                                                                                                                                                  it 'falseを返す' do
                                                                                                                                                                    expect(described_class.generate_password_reset_link(valid_email)).to be_falsey
                                                                                                                                                                  end
                                                                                                                                                                end
                                                                                                                                                              
                                                                                                                                                                describe '.refresh_token' do
                                                                                                                                                                  let(:valid_refresh_token) { 'valid_refresh_token' }
                                                                                                                                                                  let(:invalid_refresh_token) { 'invalid' }
                                                                                                                                                                  let(:success_response) do
                                                                                                                                                                    {
                                                                                                                                                                      access_token: 'new_access_token',
                                                                                                                                                                      refresh_token: 'new_refresh_token',
                                                                                                                                                                      expires_in: 3600
                                                                                                                                                                    }
                                                                                                                                                                  end
                                                                                                                                                              
                                                                                                                                                                  context '有効なリフレッシュトークンの場合' do
                                                                                                                                                                    before do
                                                                                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                                        .with(
                                                                                                                                                                          body: {
                                                                                                                                                                            grant_type: 'refresh_token',
                                                                                                                                                                            refresh_token: valid_refresh_token
                                                                                                                                                                          },
                                                                                                                                                                          headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                                        )
                                                                                                                                                                        .to_return(status: 200, body: success_response.to_json)
                                                                                                                                                                    end
                                                                                                                                                              
                                                                                                                                                                    it '新しいトークンデータを返す' do
                                                                                                                                                                      result = described_class.refresh_token(valid_refresh_token)
                                                                                                                                                                      expect(result[:access_token]).to eq('new_access_token')
                                                                                                                                                                      expect(result[:refresh_token]).to eq('new_refresh_token')
                                                                                                                                                                    end
                                                                                                                                                                  end
                                                                                                                                                              
                                                                                                                                                                  context '無効なリフレッシュトークンの場合' do
                                                                                                                                                                    before do
                                                                                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                                        .with(
                                                                                                                                                                          body: {
                                                                                                                                                                            grant_type: 'refresh_token',
                                                                                                                                                                            refresh_token: invalid_refresh_token
                                                                                                                                                                          },
                                                                                                                                                                          headers: { 'Content-Type' => 'application/json' }
                                                                                                                                                                        )
                                                                                                                                                                        .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
                                                                                                                                                                    end
                                                                                                                                                              
                                                                                                                                                                    it 'nilを返す' do
                                                                                                                                                                      expect(described_class.refresh_token(invalid_refresh_token)).to be_nil
                                                                                                                                                                    end
                                                                                                                                                                  end
                                                                                                                                                              
                                                                                                                                                                  context 'Supabase APIエラーの場合' do
                                                                                                                                                                    before do
                                                                                                                                                                      stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token")
                                                                                                                                                                        .to_return(status: 500)
                                                                                                                                                                    end
                                                                                                                                                              
                                                                                                                                                                    it 'nilを返す' do
                                                                                                                                                                      expect(described_class.refresh_token(valid_refresh_token)).to be_nil
                                                                                                                                                                    end
                                                                                                                                                                  end
                                                                                                                                                                end
                                                                                                                                                              end
                                                                                                                                                            end
                                                                                                                                                          end
                                                                                                                                                        end
                                                                                                                                                      end
                                                                                                                                                    end
                                                                                                                                                  end
                                                                                                                                                end
                                                                                                                                              end
                                                                                                                                            end
                                                                                                                                          end
                                                                                                                                        end
                                                                                                                                      end
                                                                                                                                    end
                                                                                                                                  end
                                                                                                                                end
                                                                                                                              end
                                                                                                                            end
                                                                                                                          end
                                                                                                                        end
                                                                                                                      end
                                                                                                                    end
                                                                                                                  end
                                                                                                                end
                                                                                                              end
                                                                                                            end
                                                                                                          end
                                                                                                        end
                                                                                                      end
                                                                                                    end
                                                                                                  end
                                                                                                end
                                                                                              end
                                                                                            end
                                                                                          end
                                                                                        end
                                                                                      end
                                                                                    end
                                                                                  end
                                                                                end
                                                                              end
                                                                            end
                                                                          end
                                                                        end
                                                                      end
                                                                    end
                                                                  end
                                                                end
                                                              end
                                                            end
                                                          end
                                                        end
                                                      end
                                                    end
                                                  end
                                                end
                                              end
                                            end
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
    
        context '無効なリフレッシュトークンの場合' do
          before do
            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
              .with(body: { refresh_token: 'invalid_token' })
              .to_return(status: 401, body: { error: 'Invalid refresh token' }.to_json)
          end
    
          it 'nilを返す' do
            expect(described_class.refresh_token('invalid_token')).to be_nil
          end
        end
    
        context 'Supabase APIエラーの場合' do
          before do
            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/token?grant_type=refresh_token")
              .to_return(status: 500)
          end
    
          it 'nilを返す' do
            expect(described_class.refresh_token(valid_refresh_token)).to be_nil
          end
        end
      end
    end

    context '既に登録済みのメールアドレスの場合' do
      before do
        stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/signup")
          .to_return(status: 400, body: { error: 'User already registered' }.to_json)
      end

      it 'エラーを返す' do
        result = described_class.sign_up(user_email, user_password, user_name)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('このメールアドレスは既に登録されています')
      end
    end
  end

  describe '.get_user_profile' do
    context 'プロフィールが存在する場合' do
      before do
        stub_request(:get, "http://supabase_kong_notetree:8000/rest/v1/profiles?id=eq.#{user_id}&select=*")
          .to_return(status: 200, body: [{ name: user_name }].to_json)
      end

      it 'プロフィール情報を返す' do
        result = described_class.get_user_profile(user_id)
        expect(result['name']).to eq(user_name)
      end
    end

    context 'プロフィールが存在しない場合' do
      before do
        stub_request(:get, "http://supabase_kong_notetree:8000/rest/v1/profiles?id=eq.#{user_id}&select=*")
          .to_return(status: 200, body: [].to_json)
      end

      it 'nilを返す' do
        expect(described_class.get_user_profile(user_id)).to be_nil
      end
    end
  end

  describe '.create_user_profile' do
    context '正常に作成できる場合' do
      before do
        stub_request(:post, "http://supabase_kong_notetree:8000/rest/v1/profiles")
          .to_return(status: 201)
      end

      it 'trueを返す' do
        expect(described_class.create_user_profile(user_id, user_email, user_name)).to be true
      end
    
      describe '.generate_password_reset_link' do
        let(:reset_link) { 'https://example.com/reset-password?token=reset_token' }
    
        context '有効なメールアドレスの場合' do
          before do
            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
              .with(body: { email: user_email })
              .to_return(status: 200, body: {}.to_json)
          end
    
          it 'trueを返す' do
            expect(described_class.generate_password_reset_link(user_email)).to be true
          end
        end
    
        context '無効なメールアドレスの場合' do
          before do
            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
              .with(body: { email: 'invalid@example.com' })
              .to_return(status: 400, body: { error: 'Invalid email' }.to_json)
          end
    
          it 'falseを返す' do
            expect(described_class.generate_password_reset_link('invalid@example.com')).to be false
          end
        end
    
        context 'Supabase APIエラーの場合' do
          before do
            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
              .to_return(status: 500)
          end
    
          it 'falseを返す' do
            expect(described_class.generate_password_reset_link(user_email)).to be false
          end
        end
    
        context 'ネットワークエラーの場合' do
          before do
            stub_request(:post, "http://supabase_kong_notetree:8000/auth/v1/recover")
              .to_raise(Net::ReadTimeout)
          end
    
          it 'falseを返す' do
            expect(described_class.generate_password_reset_link(user_email)).to be false
          end
        end
      end
    end

    context '作成に失敗する場合' do
      before do
        stub_request(:post, "http://supabase_kong_notetree:8000/rest/v1/profiles")
          .to_return(status: 400)
      end

      it 'falseを返す' do
        expect(described_class.create_user_profile(user_id, user_email, user_name)).to be false
      end
    end
  end
end
