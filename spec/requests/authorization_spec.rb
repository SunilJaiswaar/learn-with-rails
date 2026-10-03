require "rails_helper"

# Role-based access control (spec 73).
RSpec.describe "Authorization", type: :request do
  let(:learner) { create(:user) }
  let(:admin) { create(:user, :admin) }

  describe "the admin area" do
    it "is closed to learners" do
      sign_in_as(learner)

      get admin_root_path

      expect(response).to redirect_to(dashboard_path)
    end

    it "is closed to anonymous visitors" do
      get admin_root_path

      expect(response).to redirect_to(login_path)
    end

    it "is open to admins" do
      sign_in_as(admin)

      get admin_root_path

      expect(response).to have_http_status(:ok)
    end

    it "keeps learner management admin-only even for authors" do
      sign_in_as(create(:user, :author))

      get admin_users_path

      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe "cross-user data access" do
    it "does not let one learner open another's interview" do
      other = create(:user)
      interview = create(:interview, user: other)
      sign_in_as(learner)

      get interview_path(interview)

      expect(response).to have_http_status(:not_found)
    end

    it "does not let one learner answer another's interview" do
      other = create(:user)
      interview = create(:interview, user: other)
      interview_question = create(:interview_question, interview: interview)
      sign_in_as(learner)

      post interview_answers_path(interview_id: interview.id),
           params: { interview_question_id: interview_question.id, body: "hi" }

      expect(response).to have_http_status(:not_found)
      expect(InterviewAnswer.count).to eq(0)
    end
  end

  describe "an admin changing roles" do
    it "cannot change their own role" do
      sign_in_as(admin)

      patch admin_user_path(admin), params: { user: { role: "learner" } }

      expect(admin.reload.role).to eq("admin")
    end

    it "can promote another user and records it in the audit log" do
      sign_in_as(admin)
      target = create(:user)

      patch admin_user_path(target), params: { user: { role: "author" } }

      expect(target.reload.role).to eq("author")
      expect(AuditLog.where(action: "admin.user.role_change")).to exist
    end
  end
end
