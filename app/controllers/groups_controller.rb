class GroupsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group, only: [:show, :edit, :update, :destroy, :switch_to]
  before_action :ensure_group_access, only: [:show]
  before_action :ensure_group_management, only: [:edit, :update, :destroy]
  
  def index
    @owned_groups = current_user.owned_groups.includes(:users, :memos)
    @member_groups = current_user.groups.includes(:owner, :memos)
    @current_group = session[:current_group_id] ? Group.find_by(id: session[:current_group_id]) : nil
  end
  
  def show
    @members = @group.members.includes(:user_groups)
    @memos = @group.memos.includes(:user, :tags).accessible_by(current_user).recent.limit(10)
    @pending_invitations = @group.invitations.pending.includes(:invited_by)
    @can_manage = @group.can_manage?(current_user_model)
  end
  
  def new
    @group = Group.new
  end
  
  def create
    @group = current_user.owned_groups.build(group_params)
    
    if @group.save
      # オーナーを自動的にメンバーとして追加
      @group.user_groups.create!(user: current_user, role: 'owner')
      
      # 作成したグループに自動切り替え
      session[:current_group_id] = @group.id
      
      redirect_to @group, notice: 'グループが正常に作成されました。'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @group.update(group_params)
      redirect_to @group, notice: 'グループが正常に更新されました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @group.destroy
    
    # 削除されたグループが現在のグループの場合、セッションをクリア
    if session[:current_group_id] == @group.id
      session.delete(:current_group_id)
    end
    
    redirect_to groups_path, notice: 'グループが削除されました。'
  end
  
  def switch_to
    # 個人モードへの切り替えを処理
    if params[:id] == 'personal' || params[:personal]
      session.delete(:current_group_id)
      
      respond_to do |format|
        format.html { redirect_to memos_path, notice: '個人メモに切り替えました。' }
        format.json { render json: { success: true, group: { id: nil, name: '個人メモ' } } }
      end
      return
    end
    
    if current_user.can_access_group?(@group)
      session[:current_group_id] = @group.id
      
      respond_to do |format|
        format.html { redirect_to memos_path, notice: "#{@group.name}に切り替えました。" }
        format.json { render json: { success: true, group: { id: @group.id, name: @group.name } } }
      end
    else
      respond_to do |format|
        format.html { redirect_to groups_path, alert: 'このグループにアクセスする権限がありません。' }
        format.json { render json: { success: false, error: 'Access denied' }, status: :forbidden }
      end
    end
  end
  
  private
  
  def set_group
    return if params[:id] == 'personal' # 個人モードの場合はスキップ
    
    @group = Group.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to groups_path, alert: 'グループが見つかりません。'
  end
  
  def ensure_group_access
    unless current_user_model.can_access_group?(@group)
      redirect_to groups_path, alert: 'このグループにアクセスする権限がありません。'
    end
  end
  
  def ensure_group_management
    unless @group.can_manage?(current_user_model)
      redirect_to @group, alert: 'この操作を実行する権限がありません。'
    end
  end
  
  def group_params
    params.require(:group).permit(:name, :description)
  end
end 
