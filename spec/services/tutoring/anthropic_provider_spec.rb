require "rails_helper"

# The model-backed provider cannot be exercised against the real API here, so
# these specs pin the contract that matters: the request shape, that grading
# stays on the rubric, that a failure degrades instead of raising, and that the
# reference solution is never sent.
RSpec.describe Tutoring::AnthropicProvider do
  subject(:provider) { described_class.new }

  let(:challenge) do
    create(:challenge, title: "Double it", prompt: "Double the number.",
           reference_solution: "def double(n); n * 2; end")
  end
  let(:attempt) do
    create(:challenge_attempt_stub_for_explainer,
           challenge: challenge, status: :failed, tests_passed: 1, tests_total: 2,
           submitted_code: "def double(n); n + 2; end",
           results: { "tests" => [ { "name" => "doubles 3", "passed" => false,
                                     "expected" => "6", "actual" => "5" } ] })
  end

  # Minimal stand-ins for the SDK's polymorphic content blocks.
  def text_block(text)
    Struct.new(:type, :text).new(:text, text)
  end

  def response_with(blocks)
    Struct.new(:content).new(blocks)
  end

  describe "#explain_attempt" do
    it "parses the model's JSON into an explanation marked as model-sourced" do
      fake = instance_double("Anthropic::Client")
      messages = double("messages")
      allow(fake).to receive(:messages).and_return(messages)
      allow(messages).to receive(:create).and_return(
        response_with([ text_block('{"headline":"Off by one.","detail":"d","next_step":"n"}') ])
      )
      allow(provider).to receive(:client).and_return(fake)

      result = provider.explain_attempt(attempt)

      expect(result.headline).to eq("Off by one.")
      expect(result.source).to eq("model")
    end

    it "ignores non-text blocks when collecting the reply" do
      thinking = Struct.new(:type, :thinking).new(:thinking, "...")
      fake = instance_double("Anthropic::Client")
      messages = double("messages")
      allow(fake).to receive(:messages).and_return(messages)
      allow(messages).to receive(:create).and_return(
        response_with([ thinking, text_block('{"headline":"h","detail":"d","next_step":"n"}') ])
      )
      allow(provider).to receive(:client).and_return(fake)

      expect(provider.explain_attempt(attempt).headline).to eq("h")
    end

    it "falls back to the rubric when the reply is not usable JSON" do
      fake = instance_double("Anthropic::Client")
      messages = double("messages")
      allow(fake).to receive(:messages).and_return(messages)
      allow(messages).to receive(:create).and_return(response_with([ text_block("sorry") ]))
      allow(provider).to receive(:client).and_return(fake)

      expect(provider.explain_attempt(attempt).source).to eq("rules")
    end

    it "falls back to the rubric when the call raises" do
      allow(provider).to receive(:client).and_raise(StandardError, "network down")

      result = provider.explain_attempt(attempt)

      expect(result.source).to eq("rules")
      expect(result.next_step).to be_present
    end

    it "never sends the reference solution to the model" do
      prompt = provider.send(:prompt_for, attempt)

      expect(prompt).to include("def double(n); n + 2; end")
      expect(prompt).not_to include("n * 2")
    end

    it "sends the failing assertion's expected and actual values" do
      prompt = provider.send(:prompt_for, attempt)

      expect(prompt).to match(/doubles 3.*expected 6, got 5/)
    end
  end

  describe "#evaluate_answer" do
    it "keeps grading on the rubric so a score stays reproducible" do
      question = create(:question, answer_key: { "keywords" => %w[index] })

      result = provider.evaluate_answer(question: question,
                                        answer: "An index avoids a scan of every row.")

      expect(result.matched).to include("index")
    end
  end
end
