module Mastery
  # Builds the interview-readiness view (spec 63): per-category standing with
  # an explicit "Not tested" state rather than one misleading overall score.
  class Report
    CATEGORIES = {
      "Programming" => %w[ruby-basics ruby-collections ruby-blocks],
      "Algorithms" => %w[algorithmic-thinking searching sorting complexity],
      "Data Structures" => %w[arrays-strings hash-maps],
      "SQL" => %w[sql-basics sql-joins sql-aggregation],
      "Databases" => %w[query-performance indexing],
      "Debugging" => %w[debugging-skill]
    }.freeze

    def initialize(user:)
      @user = user
    end

    def call
      progresses = user.skill_progresses.includes(:skill).index_by { |p| p.skill.slug }

      CATEGORIES.filter_map do |label, slugs|
        tracked = slugs.filter_map { |slug| progresses[slug] }
        next if slugs.empty?

        {
          category: label,
          standing: standing_for(tracked, slugs),
          score: tracked.any? ? (tracked.sum(&:composite_score) / tracked.size) : nil,
          tested_skills: tracked.size,
          total_skills: slugs.size
        }
      end
    end

    # Weakest areas drive the dashboard's "practise this next" prompt.
    def weakest(limit: 3)
      user.skill_progresses
          .includes(:skill)
          .where(mastery_level: %i[weak developing])
          .sort_by(&:composite_score)
          .first(limit)
    end

    private

    attr_reader :user

    def standing_for(tracked, slugs)
      return "Not tested" if tracked.empty?
      # Partial coverage must not read as a verdict on the whole category.
      return "Partially tested" if tracked.size < slugs.size && tracked.size < 2

      average = tracked.sum(&:composite_score) / tracked.size
      case average
      when 70.. then "Strong"
      when 45...70 then "Developing"
      else "Weak"
      end
    end
  end
end
