require "rails_helper"

RSpec.describe Tutoring::Provider do
  before { described_class.reset! }
  after { described_class.reset! }

  it "uses the rubric provider with no API key" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil)

    expect(described_class.current).to be_a(Tutoring::RuleBasedProvider)
    expect(described_class.current).not_to be_model_backed
  end

  it "reports which backend is in use" do
    allow(described_class).to receive(:model_backed_available?).and_return(false)

    expect(described_class.describe).to eq("rubric")
  end

  it "selects the model-backed provider when a key and the gem are present" do
    allow(described_class).to receive(:model_backed_available?).and_return(true)

    expect(described_class.current).to be_a(Tutoring::AnthropicProvider)
  end

  it "defaults to the current Opus model id" do
    expect(described_class.model).to eq("claude-opus-5")
  end

  it "honours an explicit model override" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("ANTHROPIC_MODEL", "claude-opus-5")
                                 .and_return("claude-sonnet-5")

    expect(described_class.model).to eq("claude-sonnet-5")
  end

  it "treats a missing gem as unavailable even with a key present" do
    allow(described_class).to receive(:api_key).and_return("sk-test")
    allow(described_class).to receive(:require).with("anthropic").and_raise(LoadError)

    expect(described_class.model_backed_available?).to be(false)
  end
end
