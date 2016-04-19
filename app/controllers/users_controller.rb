class UsersController < ApplicationController
	http_basic_authenticate_with name: "admin", password: "admin", only: [:index, :destroy]

	def new
		@user = User.new
	end
	
	def create
		@user = User.new(user_params)
		@user.point = 0
		if @user.save
			redirect_to @user
		else
			render 'new'
		end
	end

	def show
		@user = User.find(params[:id])
	end

	def index
		@users = User.all
	end

	def edit
		@user = User.find(params[:id])
	end

	def update
		@user = User.find(params[:id])
		if @user.update(user_params)
			redirect_to users_path
		else
			render 'edit'
		end
	end

	def destroy
		@user = User.find(params[:id])
		@user.destroy
		redirect_to users_path
	end

	private
		def user_params
			params.require(:user).permit(:username, :email, :password, :password_confirmation,
				:fullname, :province, :status, :school)
		end  
end
