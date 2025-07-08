class InvitationsController < ApplicationController
  before_action :authenticate_user!
  
  def accept
    @invitation = Invitation.find_by(token: params[:token])
    
    if @invitation.nil?
      redirect_to root_path, alert: '無効な招待リンクです。'
      return
    end
    
    if @invitation.expired?
      redirect_to root_path, alert: '招待リンクの有効期限が切れています。'
      return
    end
    
    if @invitation.accepted?
      redirect_to @invitation.group, notice: 'この招待は既に承認済みです。'
      return
    end
    
    # 招待されたユーザーと現在のユーザーが一致するかチェック
    if @invitation.invited_user && @invitation.invited_user != current_user
      redirect_to root_path, alert: 'この招待は他のユーザー宛です。'
      return
    end
    
    # メールアドレスが一致するかチェック（招待されたユーザーが設定されていない場合）
    if @invitation.invited_user.nil? && @invitation.email != current_user.email
      redirect_to root_path, alert: 'この招待は他のメールアドレス宛です。'
      return
    end
    
    if @invitation.accept!(current_user)
      # グループに切り替え
      session[:current_group_id] = @invitation.group.id
      redirect_to @invitation.group, notice: "#{@invitation.group.name}に参加しました。"
    else
      redirect_to root_path, alert: 'グループへの参加に失敗しました。'
    end
  end
end 
