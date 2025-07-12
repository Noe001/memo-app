class SettingsController < ApplicationController
  before_action :authenticate_user!
  
  def show
    @user = current_user
  end
  
  def update
    @user = current_user_model
    
    if @user.update(settings_params)
      render json: { 
        status: 'success', 
        message: '設定が保存されました',
        theme: @user.theme
      }
    else
      render json: { 
        status: 'error', 
        message: '設定の保存に失敗しました',
        errors: @user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def settings_params
    params.require(:user).permit(:theme, :keyboard_shortcuts_enabled)
  end
end 
