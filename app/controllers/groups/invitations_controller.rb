class Groups::InvitationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group
  before_action :ensure_group_management
  
  def create
    @invitation = @group.invitations.build(invitation_params)
    @invitation.invited_by = current_user
    
    # 既存ユーザーをチェック
    if params[:invitation][:email].present?
      existing_user = User.find_by(email: params[:invitation][:email])
      @invitation.invited_user = existing_user if existing_user
    end
    
    if @invitation.save
      # TODO: メール送信の実装
      # InvitationMailer.invite(@invitation).deliver_now
      
      redirect_to @group, notice: '招待を送信しました。'
    else
      redirect_to @group, alert: '招待の送信に失敗しました。'
    end
  end
  
  def destroy
    @invitation = @group.invitations.find(params[:id])
    @invitation.destroy
    
    redirect_to @group, notice: '招待をキャンセルしました。'
  end
  
  private
  
  def set_group
    @group = Group.find(params[:group_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to groups_path, alert: 'グループが見つかりません。'
  end
  
  def ensure_group_management
    unless @group.can_manage?(current_user)
      redirect_to @group, alert: 'この操作を実行する権限がありません。'
    end
  end
  
  def invitation_params
    params.require(:invitation).permit(:email, :role)
  end
end 
