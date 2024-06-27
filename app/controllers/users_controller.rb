class UsersController < ApplicationController

  def signup
  end

  def create
    @user_new = 
  end

  private

  def users_params
    params.require(:users).permit(:email, :password)
  end

  def set_user
    @user = User.find_by(email: params[:email])
  end

end
