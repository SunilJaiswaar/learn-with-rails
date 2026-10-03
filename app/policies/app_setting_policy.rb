class AppSettingPolicy < ApplicationPolicy
  def index?  = admin?
  def update? = admin?
end
