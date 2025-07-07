class ErrorsController < ApplicationController
  # エラーページは認証不要
  
  def not_found
    flash[:alert] = "ページが見つかりません"
    redirect_to root_path
  end
end
