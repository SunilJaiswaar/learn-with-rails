module Admin
  # Content analytics (spec 61): which topics hurt, where learners stop.
  class Analytics
    def call
      {
        hardest_challenges: hardest_challenges,
        most_hinted: most_hinted,
        drop_off_topics: drop_off_topics,
        weakest_skills: weakest_skills,
        completion_rate: completion_rate
      }
    end

    private

    # Lowest first-pass success rate, among challenges with real traffic.
    def hardest_challenges
      rows = ChallengeAttempt.group(:challenge_id)
                             .select("challenge_id, COUNT(*) AS attempts, " \
                                     "SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) AS passes")
                             .having("COUNT(*) >= 3")
      challenges = Challenge.where(id: rows.map(&:challenge_id)).index_by(&:id)

      rows.map do |row|
        {
          challenge: challenges[row.challenge_id],
          attempts: row.attempts,
          pass_rate: ((row.passes.to_f / row.attempts) * 100).round
        }
      end.compact.sort_by { |r| r[:pass_rate] }.first(8)
    end

    def most_hinted
      counts = HintReveal.joins(hint: :challenge)
                         .group("challenges.id", "challenges.title")
                         .order(Arel.sql("COUNT(*) DESC"))
                         .limit(8)
                         .count
      counts.map { |(_id, title), count| { title: title, reveals: count } }
    end

    # Topics started but rarely finished point at a content problem.
    def drop_off_topics
      rows = TopicCompletion.group(:topic_id)
                            .select("topic_id, COUNT(*) AS started, " \
                                    "SUM(CASE WHEN completed_at IS NULL THEN 1 ELSE 0 END) AS abandoned")
                            .having("COUNT(*) >= 2")
      topics = Topic.where(id: rows.map(&:topic_id)).index_by(&:id)

      rows.map do |row|
        {
          topic: topics[row.topic_id],
          started: row.started,
          abandon_rate: ((row.abandoned.to_f / row.started) * 100).round
        }
      end.compact.sort_by { |r| -r[:abandon_rate] }.first(8)
    end

    def weakest_skills
      SkillProgress.joins(:skill)
                   .group("skills.id", "skills.name")
                   .order(Arel.sql("AVG(implementation_score) ASC"))
                   .limit(8)
                   .average(:implementation_score)
                   .map { |(_id, name), avg| { skill: name, average: avg.to_f.round } }
    end

    def completion_rate
      started = TopicCompletion.count
      return 0 if started.zero?

      ((TopicCompletion.finished.count.to_f / started) * 100).round
    end
  end
end
