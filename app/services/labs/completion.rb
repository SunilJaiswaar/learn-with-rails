module Labs
  # The single path every lab takes when a learner succeeds at it.
  #
  # Each lab previously awarded XP inline and nothing else, so lab work never
  # reached the mastery model, the revision queue or the streak. Routing them
  # all through here means hands-on practice counts as the evidence it is.
  class Completion
    Outcome = Struct.new(:xp, :skill, :award, keyword_init: true)

    DEFAULT_SCORE = 85

    def initialize(user:, lab_key:, xp:, reason:, detail: nil, score: DEFAULT_SCORE)
      @user = user
      @lab_key = lab_key.to_s
      @xp = xp
      @reason = reason
      @detail = detail
      @score = score
    end

    def call
      lab = Catalogue.find(@lab_key)
      return Outcome.new(xp: 0, skill: nil, award: nil) if lab.nil? || @user.nil?

      award = grant_xp
      skill = Catalogue.skill_for(@lab_key)
      record_evidence(lab, skill) if skill

      Gamification::StreakTracker.new(user: @user).record_activity!
      Learning::QuestProgress.new(user: @user).sync!(kind: "lab")

      Outcome.new(xp: award&.awarded.to_i, skill: skill, award: award)
    end

    private

    # Keyed on the lab and the specific accomplishment, so repeating a lab is
    # free practice rather than a second payout.
    def grant_xp
      Gamification::XpAward.new(
        user: @user, amount: @xp, reason: @reason,
        idempotency_key: idempotency_key
      ).call
    end

    def idempotency_key
      [ "lab", @lab_key, @detail ].compact.join(":")
    end

    # Labs are practice, so they move the dimension they exercise rather than
    # counting as a full demonstration — the recorder's moving average keeps a
    # single lab run from minting mastery on its own.
    def record_evidence(lab, skill)
      Mastery::Recorder.new(
        user: @user, skill: skill, dimension: lab[:dimension],
        score: @score, correct: true
      ).call

      Learning::SpacedRepetition.new(user: @user)
                                .record!(reviewable: skill, correct: true, skill: skill)
    end
  end
end
