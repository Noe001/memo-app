module Api
  module V2
    class MemosController < Api::BaseController
      before_action :authenticate_user!
      before_action :set_memo, only: [:show, :update, :destroy]
      before_action :authorize_read_access!, only: [:show]
      before_action :authorize_write_access!, only: [:update, :destroy]

      def index
        memos = filter_sort_paginate(current_user_model.memos)
        render_success({
          memos: serialize_memos(memos),
          pagination: pagination_data(memos)
        })
      end

      def public_memos
        memos = filter_sort_paginate(Memo.public_memo)
        render_success({
          memos: serialize_memos(memos),
          pagination: pagination_data(memos)
        })
      end

      def show
        render_success({ memo: serialize_memo(@memo) })
      end

      def create
        memo = current_user_model.memos.build(memo_params)
        if memo.save
          render_success({ memo: serialize_memo(memo) }, status: :created, message: 'メモを作成しました。')
        else
          render_error('メモの作成に失敗しました。', :unprocessable_entity, memo.errors.full_messages)
        end
      end

      def update
        if @memo.update(memo_params)
          render_success({ memo: serialize_memo(@memo) }, message: 'メモを更新しました。')
        else
          render_error('メモの更新に失敗しました。', :unprocessable_entity, @memo.errors.full_messages)
        end
      end

      def destroy
        @memo.destroy
        render_success(nil, :no_content)
      end

      private

      def set_memo
        @memo = Memo.find_by(id: params[:id])
        render_error('メモが見つかりません。', :not_found) unless @memo
      end

      def authorize_read_access!
        render_error('このメモを閲覧する権限がありません。', :forbidden) unless @memo.viewable_by?(current_user_model)
      end

      def authorize_write_access!
        # Re-using the method from ApplicationController
        authorize_owner!(@memo, message: 'このメモを編集または削除する権限がありません。')
      end

      def memo_params
        params.require(:memo).permit(:title, :description, :visibility, :tags_string, :group_id)
      end

      def filter_sort_paginate(scope)
        scope = scope.includes(:tags, :user)
        
        if params[:search].present?
          scope = scope.search(params[:search])
        end
        
        if params[:tags].present?
          tag_names = params[:tags].is_a?(Array) ? params[:tags] : params[:tags].to_s.split(',')
          scope = scope.with_tags(tag_names.map(&:strip))
        end

        sort_by = params[:sort_by] || 'updated_at'
        direction = params[:direction] || 'desc'
        scope = scope.apply_sort(sort_by, direction)

        scope.page(params[:page] || 1).per(params[:per_page] || 20)
      end

      def serialize_memos(memos)
        memos.map { |memo| serialize_memo(memo) }
      end

      def serialize_memo(memo)
        {
          id: memo.id,
          title: memo.title,
          description: memo.description,
          visibility: memo.visibility,
          group_id: memo.group_id,
          created_at: memo.created_at,
          updated_at: memo.updated_at,
          user: {
            id: memo.user.id,
            name: memo.user.name
          },
          tags: memo.tags.map { |tag| { id: tag.id, name: tag.name } }
        }
      end

      def pagination_data(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value
        }
      end
    end
  end
end
