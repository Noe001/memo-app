module Api
  module V2
    class GroupsController < BaseController
      before_action :authenticate_api_user!
      before_action :set_group, only: [:show, :update, :destroy, :switch_to]
      before_action :ensure_group_access, only: [:show]
      before_action :ensure_group_management, only: [:update, :destroy]

      def index
        @owned_groups = current_user.owned_groups.includes(:users, :memos)
        @member_groups = current_user.groups.includes(:owner, :memos)
        render json: {
          owned_groups: @owned_groups,
          member_groups: @member_groups
        }
      end

      def show
        @members = @group.members.includes(:user_groups)
        @memos = @group.memos.includes(:user, :tags).accessible_by(current_user).recent.limit(10)
        @pending_invitations = @group.invitations.pending.includes(:invited_by)
        render json: {
          group: @group,
          members: @members,
          memos: @memos,
          pending_invitations: @pending_invitations,
          can_manage: @group.can_manage?(current_user)
        }
      end

      def create
        @group = current_user.owned_groups.build(group_params)
        if @group.save
          @group.user_groups.create!(user: current_user, role: 'owner')
          render json: @group, status: :created
        else
          render json: { errors: @group.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @group.update(group_params)
          render json: @group
        else
          render json: { errors: @group.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @group.destroy
        head :no_content
      end

      def switch_to
        if params[:id] == 'personal'
          render json: { success: true, group: { id: nil, name: '個人メモ' } }
          return
        end

        if current_user.can_access_group?(@group)
          render json: { success: true, group: { id: @group.id, name: @group.name } }
        else
          render json: { success: false, error: 'Access denied' }, status: :forbidden
        end
      end

      private

      def set_group
        return if params[:id] == 'personal'
        @group = Group.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Group not found' }, status: :not_found
      end

      def ensure_group_access
        unless current_user.can_access_group?(@group)
          render json: { error: 'Access denied' }, status: :forbidden
        end
      end

      def ensure_group_management
        unless @group.can_manage?(current_user)
          render json: { error: 'Management access denied' }, status: :forbidden
        end
      end

      def group_params
        params.require(:group).permit(:name, :description)
      end
    end
  end
end 
