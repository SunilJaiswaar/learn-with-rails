require "rails_helper"

RSpec.describe TechnologyVersion do
  # docs_url reaches a link_to href, so an unsafe scheme would execute on
  # click. Two layers guard it: this validation stops bad data arriving, and
  # #safe_docs_url defends rows written before the validation existed.
  describe "docs_url validation" do
    subject(:version) { build(:technology_version) }

    it "accepts an https URL" do
      version.docs_url = "https://docs.ruby-lang.org/en/3.4/"
      expect(version).to be_valid
    end

    it "accepts a blank URL" do
      version.docs_url = ""
      expect(version).to be_valid
    end

    it "rejects a javascript: URL" do
      version.docs_url = "javascript:alert(document.cookie)"
      expect(version).not_to be_valid
      expect(version.errors[:docs_url]).to include("must be an https:// URL")
    end

    it "rejects plain http, which official documentation never needs" do
      version.docs_url = "http://example.com/docs"
      expect(version).not_to be_valid
    end

    it "rejects a data: URL" do
      version.docs_url = "data:text/html,<script>alert(1)</script>"
      expect(version).not_to be_valid
    end

    it "rejects a scheme-relative URL" do
      version.docs_url = "//evil.example.com"
      expect(version).not_to be_valid
    end

    it "rejects an https URL with whitespace smuggled in" do
      version.docs_url = "https://ok.example.com /x"
      expect(version).not_to be_valid
    end
  end

  describe "#safe_docs_url" do
    subject(:version) { build(:technology_version) }

    it "returns an https URL unchanged" do
      version.docs_url = "https://example.com/docs"
      expect(version.safe_docs_url).to eq("https://example.com/docs")
    end

    it "returns nil for a blank URL" do
      version.docs_url = nil
      expect(version.safe_docs_url).to be_nil
    end

    # Written past the validation, the way a row stored before it would be.
    it "returns nil for an unsafe scheme already in the database" do
      version.save!
      version.update_column(:docs_url, "javascript:alert(1)")

      expect(version.reload.safe_docs_url).to be_nil
    end
  end

  describe "#teachable_as_current?" do
    it "is true for current and maintained" do
      expect(build(:technology_version, status: :current)).to be_teachable_as_current
      expect(build(:technology_version, status: :maintained)).to be_teachable_as_current
    end

    it "is false for deprecated and eol, so they are never shown as current" do
      expect(build(:technology_version, status: :deprecated)).not_to be_teachable_as_current
      expect(build(:technology_version, status: :eol)).not_to be_teachable_as_current
    end
  end
end
