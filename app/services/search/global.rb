module Search
  # One query, results grouped by content type (spec 66).
  #
  # Uses ILIKE against indexed trigram columns: adequate at this scale and
  # avoids introducing a search engine before it is needed.
  class Global
    LIMIT_PER_TYPE = 6

    def initialize(query:)
      @query = query.to_s.strip
    end

    def call
      return {} if @query.length < 2

      {
        "Missions" => topics,
        "Challenges" => challenges,
        "Algorithms" => algorithms,
        "Skills" => skills,
        "Interview questions" => questions,
        "Boss battles" => bosses
      }.reject { |_label, rows| rows.empty? }
    end

    private

    def pattern
      @pattern ||= "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
    end

    def topics
      Topic.published.where("name ILIKE :q OR hook ILIKE :q OR summary ILIKE :q", q: pattern)
           .limit(LIMIT_PER_TYPE).to_a
    end

    def challenges
      Challenge.published.where("title ILIKE :q OR prompt ILIKE :q", q: pattern)
               .limit(LIMIT_PER_TYPE).to_a
    end

    def algorithms
      Algorithm.where("name ILIKE :q OR idea ILIKE :q", q: pattern)
               .limit(LIMIT_PER_TYPE).to_a
    end

    def skills
      Skill.where("name ILIKE :q OR summary ILIKE :q", q: pattern)
           .limit(LIMIT_PER_TYPE).to_a
    end

    def questions
      Question.published.where("body ILIKE :q", q: pattern).limit(LIMIT_PER_TYPE).to_a
    end

    def bosses
      BossBattle.published.where("title ILIKE :q OR scenario ILIKE :q", q: pattern)
                .limit(LIMIT_PER_TYPE).to_a
    end
  end
end
