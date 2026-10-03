# A small authoring DSL for seed content.
#
# It exists to make the shape of a complete mission obvious: every call site
# reads as the learning loop (hook -> visual -> predict -> code -> debug ->
# production -> interview -> revision), and `Topic#definition_of_done` then
# verifies nothing was skipped (spec 80).
module SeedDSL
  module_function

  def world!(slug)
    World.find_by!(slug: slug)
  end

  def skill!(slug)
    Skill.find_by!(slug: slug)
  end

  def version!(technology_slug, number)
    Technology.find_by!(slug: technology_slug).technology_versions.find_by!(number: number)
  end

  def curriculum_module!(world_slug:, slug:, name:, summary:, position:)
    CurriculumModule.find_or_create_by!(slug: slug) do |m|
      m.world = world!(world_slug)
      m.name = name
      m.summary = summary
      m.position = position
    end
  end

  # Creates a topic with one lesson and an ordered list of typed blocks.
  #
  # `blocks` is an array of [type, heading, payload] triples, which keeps the
  # content files readable top-to-bottom as the learner will experience them.
  def mission!(curriculum_module:, slug:, name:, hook:, summary:, position:,
               skill_slug:, minutes: 6, difficulty: :intro, xp: 10,
               technology: nil, blocks: [])
    topic = Topic.find_or_create_by!(slug: slug) do |t|
      t.curriculum_module = curriculum_module
      t.name = name
      t.hook = hook
      t.summary = summary
      t.position = position
      t.skill = skill!(skill_slug)
      t.estimated_minutes = minutes
      t.difficulty = difficulty
      t.xp_award = xp
      t.technology_version = technology
    end

    lesson = Lesson.find_or_create_by!(topic: topic, slug: "walkthrough") do |l|
      l.title = name
      l.position = 0
      l.estimated_minutes = minutes
    end

    blocks.each_with_index do |(type, heading, payload), index|
      block = LessonBlock.find_or_initialize_by(lesson: lesson, position: index)
      block.block_type = type
      block.heading = heading
      block.payload = payload
      block.save!
    end

    topic
  end

  # A challenge plus its assertions and hint ladder.
  #
  # `tests` entries are [name, call_expression, expected_inspect_string, hidden].
  # `hints` entries are [level, body, xp_penalty] in reveal order.
  def challenge!(slug:, title:, prompt:, topic:, skill_slug:, type: :implement,
                 difficulty: :easy, xp: 30, starter: nil, solution: nil,
                 explanation: nil, metadata: {}, tests: [], hints: [],
                 time_limit_ms: 5000)
    challenge = Challenge.find_or_create_by!(slug: slug) do |c|
      c.title = title
      c.prompt = prompt
      c.topic = topic
      c.skill = skill!(skill_slug)
      c.challenge_type = type
      c.difficulty = difficulty
      c.xp_award = xp
      c.starter_code = starter
      c.reference_solution = solution
      c.explanation = explanation
      c.metadata = metadata
      c.time_limit_ms = time_limit_ms
      c.language = :ruby
    end

    tests.each_with_index do |(name, expression, expected, hidden), index|
      test = ChallengeTest.find_or_initialize_by(challenge: challenge, position: index)
      test.name = name
      test.call_expression = expression
      test.expected = expected
      test.hidden = !!hidden
      test.save!
    end

    hints.each_with_index do |(level, body, penalty), index|
      hint = Hint.find_or_initialize_by(challenge: challenge, position: index)
      hint.level = level
      hint.body = body
      hint.xp_penalty = penalty || 2
      hint.save!
    end

    challenge
  end

  # An interview question and its probe tree (spec 43).
  #
  # `follow_ups` entries are hashes: { body:, trigger:, keywords:, expects:,
  # model:, children: [...] }.
  def question!(body:, skill_slug:, type: "scenario", band: :junior, difficulty: :medium,
                topic: nil, model: nil, explanation: nil, mistakes: nil,
                company_type: nil, interview_type: nil, options: [], answer_key: {},
                related: [], xp: 15, follow_ups: [])
    question = Question.find_or_create_by!(body: body) do |q|
      q.skill = skill!(skill_slug)
      q.topic = topic
      q.question_type = type
      q.experience_band = band
      q.difficulty = difficulty
      q.model_answer = model
      q.explanation = explanation
      q.common_mistakes = mistakes
      q.company_type = company_type
      q.interview_type = interview_type
      q.options = options
      q.answer_key = answer_key
      q.related_concepts = related
      q.xp_award = xp
    end

    attach_follow_ups(question, follow_ups, nil, 1)
    question
  end

  def attach_follow_ups(question, specs, parent, depth)
    specs.each_with_index do |spec, index|
      follow_up = QuestionFollowUp.find_or_initialize_by(question: question, body: spec[:body])
      follow_up.parent = parent
      follow_up.depth = depth
      follow_up.position = index
      follow_up.trigger_kind = spec.fetch(:trigger, "always")
      follow_up.trigger_keywords = spec.fetch(:keywords, [])
      follow_up.answer_key = { "keywords" => spec.fetch(:expects, []) }
      follow_up.model_answer = spec[:model]
      follow_up.save!

      attach_follow_ups(question, spec.fetch(:children, []), follow_up, depth + 1)
    end
  end
end

# --- SQL challenge authoring -------------------------------------------------
module SeedDSL
  module_function

  # A SQL challenge, whose expected result set is derived by *running* the
  # reference query against the live playground.
  #
  # This makes the content self-verifying: the stored expectation cannot drift
  # from what the reference solution actually returns, and an authoring mistake
  # fails the seed rather than shipping an unanswerable challenge.
  #
  # `requires` / `forbids` entries are { label:, pattern: } and let a challenge
  # insist on a technique ("a window function") or rule one out ("a subquery").
  def sql_challenge!(slug:, title:, prompt:, topic:, skill_slug:, solution:,
                     type: :implement, difficulty: :easy, xp: 35,
                     starter: nil, explanation: nil, ordered: false,
                     requires: [], forbids: [], hints: [], timeout_ms: 2_000,
                     test_name: "returns the expected rows")
    unless SqlExecution::SandboxSchema.provisioned?
      raise "The SQL playground is not provisioned. Run: rails sql_sandbox:provision"
    end

    expected = SeedDSL.expected_rows_for(solution)

    challenge = Challenge.find_or_create_by!(slug: slug) do |c|
      c.title = title
      c.prompt = prompt
      c.topic = topic
      c.skill = skill!(skill_slug)
      c.challenge_type = type
      c.difficulty = difficulty
      c.xp_award = xp
      c.language = :sql
      c.starter_code = starter || "SELECT\nFROM\n"
      c.reference_solution = solution
      c.explanation = explanation
      c.time_limit_ms = timeout_ms
      c.metadata = {
        "ordered" => ordered,
        "requires" => requires.map { |r| { "label" => r[:label], "pattern" => r[:pattern] } },
        "forbids" => forbids.map { |r| { "label" => r[:label], "pattern" => r[:pattern] } }
      }
    end

    test = ChallengeTest.find_or_initialize_by(challenge: challenge, position: 0)
    test.name = test_name
    test.expected = JSON.generate(expected)
    test.hidden = false
    test.save!

    hints.each_with_index do |(level, body, penalty), index|
      hint = Hint.find_or_initialize_by(challenge: challenge, position: index)
      hint.level = level
      hint.body = body
      hint.xp_penalty = penalty || 3
      hint.save!
    end

    challenge
  end

  # Executes an authored reference query and returns its rows, raising with a
  # useful message if the query itself is broken.
  def expected_rows_for(sql)
    result = SqlExecution::Runner.new(sql: sql, expected_rows: []).call

    if result.status == :rejected || result.status == :error || result.status == :timed_out
      raise "Reference SQL failed (#{result.status}): #{result.message}\n#{sql}"
    end

    rows = Array(result.rows)
    raise "Reference SQL returned no rows:\n#{sql}" if rows.empty?

    rows
  end
end
