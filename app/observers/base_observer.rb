class BaseObserver < ActiveRecord::Observer
  def log_info message
    Gitlab::AppLogger.info message
  end

  def current_user
    RequestStore.store[:current_user]
  end

  def current_commit
    RequestStore.current[:current_commit]
  end
end
