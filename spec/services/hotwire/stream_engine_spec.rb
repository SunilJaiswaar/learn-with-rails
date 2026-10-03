require "rails_helper"

RSpec.describe Hotwire::StreamEngine do
  let(:items) do
    [
      { "id" => "msg_1", "text" => "one" },
      { "id" => "msg_2", "text" => "two" },
      { "id" => "msg_3", "text" => "three" }
    ]
  end
  let(:content) { { "id" => "msg_99", "text" => "new" } }

  def apply(action, target, from: items)
    described_class.apply(from, action: action, target: target, content: content)
  end

  def ids(result)
    result.items.map { |item| item["id"] }
  end

  it "covers every action Turbo defines" do
    expect(described_class::ACTIONS).to contain_exactly(
      "append", "prepend", "replace", "update", "remove", "before", "after"
    )
  end

  describe "container actions" do
    it "appends to the end" do
      expect(ids(apply("append", "messages"))).to eq(%w[msg_1 msg_2 msg_3 msg_99])
    end

    it "prepends to the start" do
      expect(ids(apply("prepend", "messages"))).to eq(%w[msg_99 msg_1 msg_2 msg_3])
    end

    it "does nothing when the container id does not match" do
      result = apply("append", "msg_1")
      expect(ids(result)).to eq(%w[msg_1 msg_2 msg_3])
      expect(result).not_to be_ok
    end

    it "appends into an empty container" do
      expect(ids(apply("append", "messages", from: []))).to eq([ "msg_99" ])
    end
  end

  describe "replace versus update" do
    it "replace swaps the element, so the template's id wins" do
      result = apply("replace", "msg_2")
      expect(ids(result)).to eq(%w[msg_1 msg_99 msg_3])
      expect(result.items[1]["text"]).to eq("new")
    end

    it "update swaps only the contents, so the target's id survives" do
      result = apply("update", "msg_2")
      expect(ids(result)).to eq(%w[msg_1 msg_2 msg_3])
      expect(result.items[1]["text"]).to eq("new")
    end
  end

  describe "positional actions" do
    it "inserts before the target" do
      expect(ids(apply("before", "msg_2"))).to eq(%w[msg_1 msg_99 msg_2 msg_3])
    end

    it "inserts after the target" do
      expect(ids(apply("after", "msg_2"))).to eq(%w[msg_1 msg_2 msg_99 msg_3])
    end

    it "after the last element lands where append would" do
      expect(ids(apply("after", "msg_3"))).to eq(ids(apply("append", "messages")))
    end

    it "before the first element lands where prepend would" do
      expect(ids(apply("before", "msg_1"))).to eq(ids(apply("prepend", "messages")))
    end
  end

  describe "remove" do
    it "removes the target" do
      expect(ids(apply("remove", "msg_2"))).to eq(%w[msg_1 msg_3])
    end

    it "ignores the template it was sent with" do
      result = apply("remove", "msg_2")
      expect(result.items.map { |i| i["text"] }).to eq(%w[one three])
    end
  end

  describe "a target that is not on the page" do
    it "leaves the DOM untouched, the way Turbo silently does" do
      result = apply("replace", "msg_404")
      expect(result.items).to eq(items)
    end

    it "reports the miss, which Turbo itself does not" do
      expect(apply("replace", "msg_404")).not_to be_ok
      expect(apply("replace", "msg_404").error).to include("msg_404")
    end

    it "is silent for every element-targeting action" do
      (described_class::ACTIONS - described_class::CONTAINER_ACTIONS).each do |action|
        expect(apply(action, "nope").items).to eq(items), "#{action} mutated the DOM"
      end
    end
  end

  it "rejects an action Turbo does not have" do
    result = apply("morph", "msg_1")
    expect(result).not_to be_ok
    expect(result.items).to eq(items)
  end

  it "never mutates the list it was given" do
    frozen = items.map(&:dup)
    described_class::ACTIONS.each { |action| apply(action, "msg_2") }
    expect(items).to eq(frozen)
  end
end
