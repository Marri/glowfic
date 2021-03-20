class OauthClientsController < ApplicationController
  before_action :login_required
  before_action :get_client_application, :only => [:show, :edit, :update, :destroy]

  def index
    @client_applications = @current_user.client_applications
    @tokens = @current_user.tokens.where('oauth_tokens.invalidated_at is null and oauth_tokens.authorized_at is not null')
  end

  def new
    @client_application = ClientApplication.new
  end

  def create
    @client_application = @current_user.client_applications.build(user_params)
    if @client_application.save
      flash[:notice] = "Registered the information successfully"
      redirect_to :action => "show", :id => @client_application.id
    else
      render :action => "new"
    end
  end

  def user_params
    params.fetch(:client_application, {}).permit(:name, :callback_url, :support_url, :url)
  end

  def show
  end

  def edit
  end

  def update
    if @client_application.update(user_params)
      flash[:notice] = "Updated the client information successfully"
      redirect_to :action => "show", :id => @client_application.id
    else
      render :action => "edit"
    end
  end

  def destroy
    @client_application.destroy!
    flash[:notice] = "Destroyed the client application registration"
    redirect_to :action => "index"
  end

  private

  def get_client_application
    @client_application = @current_user.client_applications.find(params[:id])
    unless @client_application
      flash.now[:error] = "Wrong application id"
      raise ActiveRecord::RecordNotFound
    end
  end
end
