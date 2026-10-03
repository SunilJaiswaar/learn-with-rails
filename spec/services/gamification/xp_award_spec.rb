require "rails_helper"

RSpec.describe Gamification::XpAward do
  let(:user) { create(:user) }

  it "writes a ledger entry and updates the cached total" do
    outcome = described_class.new(user: user, amount: 50, reason: "Test").call

    expect(outcome.awarded).to eq(50)
    expect(user.reload.xp_total).to eq(50)
    expect(user.xp_transactions.count).to eq(1)
  end

  it "keeps the cached total equal to the ledger sum" do
    described_class.new(user: user, amount: 30, reason: "One").call
    described_class.new(user: user, amount: 20, reason: "Two").call

    expect(user.reload.xp_total).to eq(user.xp_transactions.sum(:amount))
  end

  it "pays out an accomplishment only once when given an idempotency key" do
    2.times do
      described_class.new(user: user, amount: 100, reason: "Solved",
                          idempotency_key: "challenge:1").call
    end

    expect(user.reload.xp_total).to eq(100)
    expect(user.xp_transactions.count).to eq(1)
  end

  it "allows distinct accomplishments with different keys" do
    described_class.new(user: user, amount: 10, reason: "A", idempotency_key: "a").call
    described_class.new(user: user, amount: 10, reason: "B", idempotency_key: "b").call

    expect(user.reload.xp_total).to eq(20)
  end

  it "reports a level gain when the threshold is crossed" do
    outcome = described_class.new(user: user, amount: 5_000, reason: "Big").call

    expect(outcome).to be_levelled_up
    expect(outcome.new_level).to be > 1
    expect(user.reload.level).to eq(outcome.new_level)
  end

  it "applies a negative amount, as a hint penalty does" do
    described_class.new(user: user, amount: 100, reason: "Earned").call
    described_class.new(user: user, amount: -8, reason: "Hint").call

    expect(user.reload.xp_total).to eq(92)
  end

  it "never drives the cached total below zero" do
    described_class.new(user: user, amount: -50, reason: "Penalty").call

    expect(user.reload.xp_total).to eq(0)
  end

  it "ignores a zero award" do
    outcome = described_class.new(user: user, amount: 0, reason: "Nothing").call

    expect(outcome).not_to be_awarded
    expect(user.xp_transactions).to be_empty
  end

  it "awards achievements that the new total unlocks" do
    create(:achievement, rule_key: "xp_total", threshold: 40, name: "Forty", xp_reward: 0)

    outcome = described_class.new(user: user, amount: 50, reason: "Test").call

    expect(outcome.achievements.map(&:name)).to include("Forty")
    expect(user.achievements.count).to eq(1)
  end
end
