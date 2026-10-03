class UserPolicy < ApplicationPolicy
  # Only full admins may see or change other people's accounts.
  def index?   = admin?
  def show?    = admin? || record == user
  def update?  = admin?
  def destroy? = admin? && record != user      # never delete yourself
  def change_role? = admin? && record != user  # nor escalate yourself
end
