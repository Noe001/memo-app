class ErrorsController < ApplicationController
  def not_found
    flash[:alert] = "ページが見つかりません"
    redirect_to root_path
  end
end
