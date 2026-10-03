# Role-based access control (spec 73). Learners can only ever read published
# content; authoring and user administration are staff-only.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?   = staff?
  def show?    = staff?
  def create?  = staff?
  def new?     = create?
  def update?  = staff?
  def edit?    = update?
  def destroy? = admin?

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      user&.staff? ? scope.all : scope.none
    end
  end

  private

  def staff?
    user&.staff?
  end

  def admin?
    user&.admin?
  end
end
