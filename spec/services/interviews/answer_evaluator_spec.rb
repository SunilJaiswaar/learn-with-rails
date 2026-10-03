require "rails_helper"

RSpec.describe Interviews::AnswerEvaluator do
  def evaluate(question, answer)
    described_class.new(question: question, answer: answer).call
  end

  context "with a multiple-choice question" do
    let(:question) { create(:question, :mcq) }

    it "marks the correct index correct" do
      expect(evaluate(question, "1")).to have_attributes(correct: true, score: 100)
    end

    it "marks any other index incorrect" do
      expect(evaluate(question, "0")).to have_attributes(correct: false, score: 0)
    end

    it "treats a blank answer as incorrect" do
      expect(evaluate(question, "")).to have_attributes(correct: false)
    end
  end

  context "with an open-ended question" do
    let(:question) do
      create(:question,
             answer_key: { "keywords" => %w[index selectivity rows],
                           "required" => [ "index" ] })
    end

    it "credits the concepts the answer mentions" do
      result = evaluate(question, "An index improves selectivity so fewer rows are scanned overall.")

      expect(result.matched).to include("index", "selectivity", "rows")
      expect(result.correct).to be(true)
    end

    it "lists the concepts the answer missed" do
      result = evaluate(question, "It makes the query faster because of the index lookup path.")

      expect(result.missed).to include("selectivity")
      expect(result.notes).to include("selectivity")
    end

    it "caps the score when a required concept is absent" do
      result = evaluate(question, "It is faster because fewer rows get read from disk each time.")

      expect(result.score).to be <= 45
      expect(result.correct).to be(false)
    end

    it "penalises an answer too short to show reasoning" do
      short = evaluate(question, "index selectivity rows")
      long = evaluate(question, "Using an index improves selectivity, so the planner reads far fewer rows than a sequential scan would.")

      expect(short.score).to be < long.score
    end

    it "penalises hedging" do
      confident = evaluate(question, "An index improves selectivity so the planner reads fewer rows overall.")
      hedged = evaluate(question, "I am not sure but an index improves selectivity so it reads fewer rows overall.")

      expect(hedged.score).to be < confident.score
    end

    it "scores an empty answer at zero" do
      expect(evaluate(question, "")).to have_attributes(score: 0, correct: false)
    end

    it "labels the verdict in words a learner can act on" do
      expect(evaluate(question, "").verdict).to eq("weak")
    end
  end
end
