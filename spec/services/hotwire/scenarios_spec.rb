require "rails_helper"

RSpec.describe Hotwire::Scenarios do
  describe "every scenario" do
    it "is well formed" do
      described_class.all.each do |scenario|
        expect(scenario[:title]).to be_present, "#{scenario[:slug]} has no title"
        expect(scenario[:lesson]).to be_present, "#{scenario[:slug]} has no lesson"
        expect(scenario[:xp_reward]).to be_positive, "#{scenario[:slug]} awards nothing"
        expect(Hotwire::StreamEngine::ACTIONS).to include(scenario[:action])
        expect(scenario[:confusables]).to be_present, "#{scenario[:slug]} has no distractors"
      end
    end

    it "has a unique slug" do
      expect(described_class.slugs.uniq.length).to eq(described_class.all.length)
    end

    it "offers at least two distinct options" do
      described_class.all.each do |scenario|
        options = described_class.options_for(scenario)
        expect(options.length).to be >= 2, "#{scenario[:slug]} has only one option"
        expect(options.map(&:digest).uniq.length).to eq(options.length)
      end
    end

    it "includes the correct answer among its options" do
      described_class.all.each do |scenario|
        digests = described_class.options_for(scenario).map(&:digest)
        expect(digests).to include(described_class.correct_digest(scenario)),
                           "#{scenario[:slug]} cannot be answered correctly"
      end
    end

    it "does not always put the answer in the same position" do
      positions = described_class.all.map do |scenario|
        correct = described_class.correct_digest(scenario)
        described_class.options_for(scenario).index { |option| option.digest == correct }
      end

      expect(positions.uniq.length).to be > 1
    end

    it "orders its options the same way on every call" do
      described_class.all.each do |scenario|
        first = described_class.options_for(scenario).map(&:digest)
        expect(described_class.options_for(scenario).map(&:digest)).to eq(first)
      end
    end
  end

  describe "the derived answers" do
    it "matches what the engine actually does" do
      described_class.all.each do |scenario|
        expected = Hotwire::StreamEngine.apply(
          described_class::START.map(&:dup),
          action: scenario[:action], target: scenario[:target], content: scenario[:content]
        ).items

        expect(described_class.correct_items(scenario)).to eq(expected)
      end
    end

    it "leaves the DOM unchanged for the missing-target scenario" do
      scenario = described_class.find("a-missing-target-is-silent")
      expect(described_class.correct_items(scenario)).to eq(described_class::START)
    end

    it "keeps the target's id for update and takes the template's for replace" do
      update = described_class.correct_items(described_class.find("update-keeps-the-element"))
      replace = described_class.correct_items(described_class.find("replace-swaps-the-element"))

      expect(update.map { |i| i["id"] }).to include("msg_2")
      expect(replace.map { |i| i["id"] }).to include("msg_99")
      expect(update).not_to eq(replace)
    end
  end

  describe ".correct?" do
    let(:scenario) { described_class.find("update-keeps-the-element") }

    it "accepts the derived answer" do
      expect(described_class.correct?(scenario, described_class.correct_digest(scenario))).to be(true)
    end

    it "rejects a distractor" do
      wrong = described_class.options_for(scenario)
                             .map(&:digest)
                             .reject { |d| d == described_class.correct_digest(scenario) }
                             .first
      expect(described_class.correct?(scenario, wrong)).to be(false)
    end

    it "rejects a blank or absent answer" do
      expect(described_class.correct?(scenario, "")).to be(false)
      expect(described_class.correct?(scenario, nil)).to be(false)
    end
  end

  describe ".find" do
    it "returns nil for an unknown slug" do
      expect(described_class.find("nope")).to be_nil
    end
  end
end
