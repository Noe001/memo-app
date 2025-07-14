module Api
  module V2
    module Groups
      class InvitationsController < BaseController
        before_action :authenticate_api_user!
        before_action :set_group
        before_action :ensure_group_management

        def create
          @invitation = @group.invitations.build(invitation_params)
          @invitation.invited_by = current_user

          if params[:invitation][:email].present?
            existing_user = User.find_by(email: params[:invitation][:email])
            @invitation.invited_user = existing_user if existing_user
          end

          if @invitation.save
            render json: @invitation, status: :created
          else
            render json: { errors: @invitation.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          @invitation = @group.invitations.find(params[:id])
          @invitation.destroy
          head :no_content
        end

        private

        def set_group
          @group = Group.find(params[:group_id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Group not found' }, status: :not_found
        end

        def ensure_group_management
          unless @group.can_manage?(current_user)
            render json: { error: 'Management access denied' }, status: :forbidden
          end
        end

        def invitation_params
          params.require(:invitation).permit(:email, :role)
        end
      end
    end
  end
end 
