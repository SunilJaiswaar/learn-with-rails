require "rails_helper"

RSpec.describe RailsLab::MiddlewareStack do
  it "reads the real stack rather than a hardcoded list" do
    expect(described_class.names).to eq(Rails.application.middleware.map(&:name))
  end

  # The lab teaches this stack, so an annotation falling behind a Rails or gem
  # upgrade would mean teaching a layer the lab cannot describe.
  it "has an annotation for every middleware actually installed" do
    expect(described_class.undocumented).to be_empty,
      "undocumented middleware: #{described_class.undocumented.join(', ')}"
  end

  # A duplicate registration counts every request twice against every
  # throttle. This lab is how that bug was found.
  it "finds no middleware registered twice" do
    expect(described_class.duplicates).to be_empty,
      "registered more than once: #{described_class.duplicates.join(', ')}"
  end

  describe "entries" do
    it "describes what each layer does and the evidence it leaves" do
      described_class.entries.each do |entry|
        expect(entry.does).to be_present, "#{entry.name} has no description"
        next unless entry.documented?

        expect(entry.evidence).to be_present, "#{entry.name} has no evidence"
      end
    end

    it "marks an unannotated layer rather than hiding it" do
      allow(described_class).to receive(:names).and_return([ "Some::NewMiddleware" ])
      entry = described_class.entries.first

      expect(entry).not_to be_documented
      expect(entry.does).to include("Not yet annotated")
    end

    it "preserves stack order" do
      expect(described_class.entries.map(&:name)).to eq(described_class.names)
    end
  end
end
