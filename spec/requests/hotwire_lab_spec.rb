require "rails_helper"

RSpec.describe "Hotwire Lab", type: :request do
  let(:user) { create(:user) }
  let!(:skill) { skill_at("dom-rendering", name: "DOM & Rendering") }

  before { sign_in_as(user) }

  def scenario(slug)
    Hotwire::Scenarios.find(slug)
  end

  def predict(slug, digest)
    post hotwire_lab_predict_path,
         params: { slug: slug, prediction: digest },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  def correct_answer(slug)
    Hotwire::Scenarios.correct_digest(scenario(slug))
  end

  def wrong_answer(slug)
    Hotwire::Scenarios.options_for(scenario(slug))
                      .map(&:digest)
                      .reject { |d| d == correct_answer(slug) }
                      .first
  end

  it "renders the playground and the prediction challenges" do
    get hotwire_lab_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Live Turbo Stream Playground")
    expect(response.body).to include("Predict the DOM")
    expect(response.body).to include("0/6 correct")
    expect(response.body).to include("msg_1")
  end

  describe "the live playground" do
    it "appends through a real turbo stream response" do
      post hotwire_lab_operate_path,
           params: { action_name: "append", target: "messages", text: "Cache warmed" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("turbo-stream")
      expect(response.body).to include("Cache warmed")
    end

    it "removes an element" do
      post hotwire_lab_operate_path,
           params: { action_name: "remove", target: "msg_2" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).not_to include("Running migrations")
    end

    it "explains a target that matched nothing" do
      post hotwire_lab_operate_path,
           params: { action_name: "replace", target: "msg_404", text: "x" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include("msg_404")
      expect(response.body).to include("Turbo itself")
    end

    # Scoped to the rendered <li id="..."> rather than the message text,
    # because the prediction cards display the same starting list as prose.
    it "persists the playground across requests, then resets it" do
      post hotwire_lab_operate_path,
           params: { action_name: "remove", target: "msg_2" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      get hotwire_lab_path
      expect(response.body).to include('id="msg_1"')
      expect(response.body).not_to include('id="msg_2"')

      post hotwire_lab_reset_path
      follow_redirect!
      expect(response.body).to include('id="msg_2"')
    end
  end

  describe "predicting" do
    it "awards XP and records prediction evidence for a correct answer" do
      expect { predict("update-keeps-the-element", correct_answer("update-keeps-the-element")) }
        .to change { SkillProgress.where(user: user, skill: skill).count }.from(0).to(1)

      expect(response.body).to include("Correct.")
      expect(response.body).to include("1/6 correct")

      entry = user.xp_transactions.find_by(idempotency_key: "lab:hotwire_lab:update-keeps-the-element")
      expect(entry.amount).to eq(130)
      expect(SkillProgress.find_by(user: user, skill: skill).prediction_score).to be_positive
    end

    it "awards nothing for a wrong answer and records the miss" do
      predict("update-keeps-the-element", wrong_answer("update-keeps-the-element"))

      expect(response.body).to include("Not what Turbo does.")
      expect(response.body).to include("0/6 correct")
      expect(user.xp_transactions.where("idempotency_key LIKE 'lab:hotwire_lab:%'")).to be_empty

      progress = SkillProgress.find_by(user: user, skill: skill)
      expect(progress.attempts_count).to eq(1)
      expect(progress.correct_count).to be_zero
    end

    it "teaches the lesson once the answer is revealed" do
      predict("replace-swaps-the-element", wrong_answer("replace-swaps-the-element"))
      expect(response.body).to include("replace swaps the whole element")
    end

    it "pays out once however many times it is answered again" do
      3.times { predict("remove-ignores-its-template", correct_answer("remove-ignores-its-template")) }

      expect(user.xp_transactions.where(idempotency_key: "lab:hotwire_lab:remove-ignores-its-template").count)
        .to eq(1)
    end

    it "remembers solved scenarios from the ledger, not the session" do
      predict("update-keeps-the-element", correct_answer("update-keeps-the-element"))

      # A fresh browser: new cookie jar, same account.
      reset!
      sign_in_as(user)
      get hotwire_lab_path

      expect(response.body).to include("1/6 correct")
    end

    it "is answerable correctly for every scenario" do
      Hotwire::Scenarios.slugs.each do |slug|
        predict(slug, correct_answer(slug))
        expect(response.body).to include("Correct."), "#{slug} could not be answered"
      end

      expect(response.body).to include("6/6 correct")
      expect(user.xp_transactions.where("idempotency_key LIKE 'lab:hotwire_lab:%'").count).to eq(6)
    end

    it "ignores an unknown scenario" do
      predict("not-a-scenario", "deadbeef")
      expect(response).to redirect_to(hotwire_lab_path)
    end

    it "treats a missing prediction as wrong rather than crashing" do
      post hotwire_lab_predict_path, params: { slug: "update-keeps-the-element" },
                                     headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Not what Turbo does.")
    end
  end

  it "keeps the session cookie well under the 4KB limit" do
    Hotwire::Scenarios.slugs.each { |slug| predict(slug, correct_answer(slug)) }
    10.times do |i|
      post hotwire_lab_operate_path,
           params: { action_name: "append", target: "messages", text: "message #{i}" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    cookie = response.headers["Set-Cookie"]
    cookie = cookie.first if cookie.is_a?(Array)
    expect(cookie.to_s.bytesize).to be < 4096

    get hotwire_lab_path
    expect(response).to have_http_status(:ok)
  end

  it "requires authentication" do
    delete logout_path
    get hotwire_lab_path
    expect(response).to redirect_to(login_path)
  end
end
