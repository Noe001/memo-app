module Api
  module V2
    class MemosController < BaseController
      
      def index
        begin
          # Supabaseから直接データを取得する場合
          if params[:use_supabase] == 'true'
            proxy_to_supabase('/memos', method: :get, params: {
              select: 'id,title,description,visibility,created_at,updated_at,user_id,tags(id,name)',
              user_id: "eq.#{current_user.id}",
              order: 'updated_at.desc'
            })
          else
            # 従来のRailsロジックを使用
            user_model = current_user_model
            unless user_model
              render_error('User model not found', :not_found)
              return
            end
            
            # 検索とフィルタリング
            search_word = params[:search] || params[:word]
            selected_tags = params[:tags] || []
            selected_tags = selected_tags.is_a?(Array) ? selected_tags : selected_tags.to_s.split(',')
            selected_tags.map!(&:strip)
            
            # 並べ替え
            sort_by = params[:sort_by] || 'updated_at'
            direction = params[:direction] || 'desc'
            
            # メモのクエリ構築
            scope = user_model.memos.includes(:tags)
            scope = scope.search(search_word) if search_word.present?
            scope = scope.with_tags(selected_tags) if selected_tags.present?
            scope = scope.apply_sort(sort_by, direction)
            
            # ページネーション
            page = params[:page] || 1
            per_page = params[:per_page] || 20
            
            memos = scope.page(page).per(per_page)
            
            # レスポンス構築
            render_success({
              memos: memos.map { |memo| serialize_memo(memo) },
              pagination: {
                current_page: memos.current_page,
                total_pages: memos.total_pages,
                total_count: memos.total_count,
                per_page: per_page
              },
              search: {
                query: search_word,
                tags: selected_tags
              }
            })
          end
        rescue => e
          Rails.logger.error "Error in memos#index: #{e.message}"
          render_error('メモの取得に失敗しました', :internal_server_error)
        end
      end
      
      def show
        begin
          memo = find_memo(params[:id])
          return unless memo
          
          # 読み取り権限の確認
          unless can_read_memo?(memo)
            render_error('このメモを表示する権限がありません', :forbidden)
            return
          end
          
          render_success({ memo: serialize_memo(memo) })
        rescue => e
          Rails.logger.error "Error in memos#show: #{e.message}"
          render_error('メモの取得に失敗しました', :internal_server_error)
        end
      end
      
      def create
        begin
          # Supabaseへ直接作成する場合
          if params[:use_supabase] == 'true'
            memo_data = {
              title: params[:title],
              description: params[:description],
              visibility: params[:visibility] || 'private_memo',
              user_id: current_user.id
            }
            
            proxy_to_supabase('/memos', method: :post, body: memo_data)
          else
            # 従来のRailsロジックを使用
            user_model = current_user_model
            unless user_model
              render_error('User model not found', :not_found)
              return
            end
            
            memo = user_model.memos.build(memo_params)
            
            # タグがある場合は、タイトルと説明文が空でも保存を許可
            if memo.title.blank? && memo.description.blank? && params[:tags].present?
              memo.title = "無題"
            end
            
            if memo.save
              # タグ処理
              process_tags(memo, params[:tags]) if params[:tags].present?
              
              # タグだけの場合は、一時的なタイトルを削除
              if memo.title == "無題" && memo.description.blank? && params[:tags].present?
                memo.update_column(:title, nil)
              end
              
              render_success({ memo: serialize_memo(memo) }, 'メモを作成しました')
            else
              render_error('メモの作成に失敗しました', :unprocessable_entity, memo.errors.full_messages)
            end
          end
        rescue => e
          Rails.logger.error "Error in memos#create: #{e.message}"
          render_error('メモの作成中にエラーが発生しました', :internal_server_error)
        end
      end
      
      def update
        begin
          memo = find_memo(params[:id])
          return unless memo
          
          # 編集権限の確認
          unless can_write_memo?(memo)
            render_error('このメモを編集する権限がありません', :forbidden)
            return
          end
          
          # Supabaseへ直接更新する場合
          if params[:use_supabase] == 'true'
            memo_data = {
              title: params[:title],
              description: params[:description],
              visibility: params[:visibility]
            }.compact
            
            proxy_to_supabase("/memos?id=eq.#{params[:id]}&user_id=eq.#{current_user.id}", 
                              method: :patch, body: memo_data)
          else
            # 従来のRailsロジックを使用
            temp_title_set = false
            memo_attributes = memo_params
            
            # タグがある場合は、タイトルと説明文が空でも保存を許可
            if memo_attributes[:title].blank? && memo_attributes[:description].blank? && params[:tags].present?
              memo_attributes[:title] = "無題"
              temp_title_set = true
            end
            
            if memo.update(memo_attributes)
              # タグ処理
              process_tags(memo, params[:tags]) if params[:tags].present?
              
              # タグだけの場合は、一時的なタイトルを削除
              if temp_title_set && memo.description.blank? && params[:tags].present?
                memo.update_column(:title, nil)
              end
              
              render_success({ memo: serialize_memo(memo) }, 'メモを更新しました')
            else
              render_error('メモの更新に失敗しました', :unprocessable_entity, memo.errors.full_messages)
            end
          end
        rescue => e
          Rails.logger.error "Error in memos#update: #{e.message}"
          render_error('メモの更新中にエラーが発生しました', :internal_server_error)
        end
      end
      
      def destroy
        begin
          memo = find_memo(params[:id])
          return unless memo
          
          # 削除権限の確認
          unless can_write_memo?(memo)
            render_error('このメモを削除する権限がありません', :forbidden)
            return
          end
          
          # Supabaseへ直接削除する場合
          if params[:use_supabase] == 'true'
            proxy_to_supabase("/memos?id=eq.#{params[:id]}&user_id=eq.#{current_user.id}", 
                              method: :delete)
          else
            # 従来のRailsロジックを使用
            if memo.destroy
              render_success({}, 'メモを削除しました')
            else
              render_error('メモの削除に失敗しました', :unprocessable_entity)
            end
          end
        rescue => e
          Rails.logger.error "Error in memos#destroy: #{e.message}"
          render_error('メモの削除中にエラーが発生しました', :internal_server_error)
        end
      end
      
      def search
        begin
          # 検索パラメータ
          search_word = params[:word] || params[:query]
          selected_tags = params[:tags] || []
          selected_tags = selected_tags.is_a?(Array) ? selected_tags : selected_tags.to_s.split(',')
          selected_tags.map!(&:strip)
          
          # Supabaseで検索する場合
          if params[:use_supabase] == 'true'
            search_params = {
              select: 'id,title,description,visibility,created_at,updated_at,user_id,tags(id,name)',
              user_id: "eq.#{current_user.id}",
              order: 'updated_at.desc'
            }
            
            # テキスト検索
            if search_word.present?
              search_params[:or] = "title.ilike.%#{search_word}%,description.ilike.%#{search_word}%"
            end
            
            proxy_to_supabase('/memos', method: :get, params: search_params)
          else
            # 従来のRailsロジックを使用
            user_model = current_user_model
            unless user_model
              render_error('User model not found', :not_found)
              return
            end
            
            scope = user_model.memos.includes(:tags)
            scope = scope.search(search_word) if search_word.present?
            scope = scope.with_tags(selected_tags) if selected_tags.present?
            
            # 並べ替え
            sort_by = params[:sort_by] || 'updated_at'
            direction = params[:direction] || 'desc'
            scope = scope.apply_sort(sort_by, direction)
            
            # ページネーション
            page = params[:page] || 1
            per_page = params[:per_page] || 20
            
            memos = scope.page(page).per(per_page)
            
            render_success({
              memos: memos.map { |memo| serialize_memo(memo) },
              pagination: {
                current_page: memos.current_page,
                total_pages: memos.total_pages,
                total_count: memos.total_count,
                per_page: per_page
              },
              search: {
                query: search_word,
                tags: selected_tags
              }
            })
          end
        rescue => e
          Rails.logger.error "Error in memos#search: #{e.message}"
          render_error('メモの検索中にエラーが発生しました', :internal_server_error)
        end
      end
      
      def public_memos
        begin
          # Supabaseで公開メモを取得
          if params[:use_supabase] == 'true'
            proxy_to_supabase('/memos', method: :get, params: {
              select: 'id,title,description,created_at,updated_at,user_id,tags(id,name)',
              visibility: 'eq.public_memo',
              order: 'updated_at.desc'
            })
          else
            # 従来のRailsロジックを使用
            scope = Memo.includes(:tags).where(visibility: :public_memo)
            
            # 検索
            if params[:search].present?
              scope = scope.search(params[:search])
            end
            
            # ページネーション
            page = params[:page] || 1
            per_page = params[:per_page] || 20
            
            memos = scope.page(page).per(per_page)
            
            render_success({
              memos: memos.map { |memo| serialize_memo(memo) },
              pagination: {
                current_page: memos.current_page,
                total_pages: memos.total_pages,
                total_count: memos.total_count,
                per_page: per_page
              }
            })
          end
        rescue => e
          Rails.logger.error "Error in memos#public_memos: #{e.message}"
          render_error('公開メモの取得中にエラーが発生しました', :internal_server_error)
        end
      end
      
      private
      
      def find_memo(id)
        memo = Memo.includes(:user, :tags).find_by(id: id)
        unless memo
          render_error('メモが見つかりません', :not_found)
          return nil
        end
        memo
      end
      
      def can_read_memo?(memo)
        return false unless memo && current_user_model
        
        # 自分のメモは読み取り可能
        return true if memo.user_id == current_user_model.id
        
        # 公開メモは読み取り可能
        return true if memo.visibility == 'public_memo'
        
        # 共有メモ（今後実装）
        return true if memo.visibility == 'shared'
        
        false
      end
      
      def can_write_memo?(memo)
        return false unless memo && current_user_model
        
        # 自分のメモのみ編集可能
        memo.user_id == current_user_model.id
      end
      
      def memo_params
        params.require(:memo).permit(:title, :description, :visibility, :tags_string)
      rescue ActionController::ParameterMissing
        # memoパラメータが不要な場合もある
        params.permit(:title, :description, :visibility, :tags_string)
      end
      
      def process_tags(memo, tag_names_string)
        return if tag_names_string.blank?
        
        tag_names = tag_names_string.split(',').map(&:strip).reject(&:blank?)
        
        # 既存のタグを削除
        memo.memo_tags.destroy_all
        
        tag_names.each do |tag_name|
          # タグが存在しない場合は作成
          tag = current_user_model.tags.find_or_create_by(name: tag_name)
          
          # メモとタグを関連付け
          memo.memo_tags.create(tag: tag)
        end
      end
      
      def serialize_memo(memo)
        {
          id: memo.id,
          title: memo.title,
          description: memo.description,
          visibility: memo.visibility,
          created_at: memo.created_at,
          updated_at: memo.updated_at,
          user_id: memo.user_id,
          tags: memo.tags.map { |tag| { id: tag.id, name: tag.name } }
        }
      end
    end
  end
end 
