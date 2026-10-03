module Interviews
  # Assembles an interview from a template: rounds in order, questions chosen to
  # match the band and company-pattern category.
  class Builder
    def initialize(user:, template:, pressure_mode: :normal, company_type: nil)
      @user = user
      @template = template
      @pressure_mode = pressure_mode
      @company_type = company_type.presence || template.company_type
    end

    def call
      interview = nil

      Interview.transaction do
        interview = user.interviews.create!(
          interview_template: template,
          pressure_mode: pressure_mode,
          experience_band: template.experience_band,
          company_type: company_type,
          status: :in_progress,
          started_at: Time.current
        )

        position = 0
        template.rounds.each_with_index do |spec, index|
          round = interview.interview_rounds.create!(
            name: spec.fetch("name", "Round #{index + 1}"),
            position: index
          )

          questions_for(spec).each do |question|
            interview.interview_questions.create!(
              interview_round: round,
              question: question,
              position: position,
              time_limit_seconds: interview.seconds_per_question
            )
            position += 1
          end
        end

        raise ActiveRecord::Rollback if position.zero?
      end

      return nil if interview.nil? || interview.interview_questions.empty?

      interview
    end

    private

    attr_reader :user, :template, :pressure_mode, :company_type

    def questions_for(spec)
      scope = Question.published
      scope = scope.where(skill_id: skill_ids(spec)) if spec["skills"].present?
      scope = scope.where(question_type: spec["types"]) if spec["types"].present?
      # Never ask a senior candidate only syntax questions (spec 41): questions
      # are drawn at or below the band, weighted toward the band itself.
      scope = scope.up_to_band(template.experience_band)
      scope = scope.for_company_type(company_type)

      per_round = spec.fetch("count", 2).to_i
      ordered = scope.order(Arel.sql("experience_band DESC, difficulty DESC, random()"))
      ordered.limit(per_round).to_a
    end

    def skill_ids(spec)
      Skill.where(slug: Array(spec["skills"])).pluck(:id)
    end
  end
end
