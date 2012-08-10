class ApplicationController < ActionController::Base
  include CacheCooker::Oven

  protect_from_forgery
  before_filter :authenticate_cache_cooker!
  before_filter :authenticate
  before_filter :authenticate_user
  before_filter :enable_notifications

  helper_method :current_user, :active_broadcasts

  def authenticate
    current_authorization || (store_location && redirect_to("/auth/github"))
  end

  def authenticate_user
    unless current_user
      return redirect_to(current_authorization.authorization_link)
    end

    redirect_to problems_sessions_path if current_user.account_disabled
  end

  def authenticate_cache_cooker!
    if authenticate_cache_cooker
      @current_authorization = Authorization.includes(:user).
        where('users.admin is TRUE').first
      session[:authorization_id] = @current_authorization.try(:id)
    end
  end

  def current_authorization
    @current_authorization ||= Authorization.find_by_id(session[:authorization_id])
  end

  def current_user
    current_authorization.try(:user)
  end

  def admin_only
    raise "Access Denied" unless current_user && current_user.admin
  end

  def store_location
    session[:return_to] = request.fullpath
  end

  def redirect_back_or_default(default)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end

  private

  def active_broadcasts
    if current_user
      session[:dismissed_broadcasts] ||= [-1]
      Announcement.broadcasts.where("id NOT IN (?)", session[:dismissed_broadcasts])
    else
      []
    end
  end

  def enable_notifications
    current_user.try(:enable_notifications)
  end
end
