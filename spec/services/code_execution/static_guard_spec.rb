require "rails_helper"

RSpec.describe CodeExecution::StaticGuard do
  def rejection_for(code)
    described_class.new(code).call
  end

  it "allows ordinary Ruby" do
    expect(rejection_for("def add(a, b)\n  a + b\nend")).to be_nil
  end

  it "allows string interpolation and common collection methods" do
    expect(rejection_for('def go(x) = x.map { |v| "#{v}!" }.tally')).to be_nil
  end

  %w[
    system('ls')
    exec('ls')
    `ls`
    %x{ls}
    File.write('/tmp/x','y')
    FileUtils.rm_rf('/')
  ].each do |snippet|
    it "rejects #{snippet}" do
      expect(rejection_for("def go\n  #{snippet}\nend")).not_to be_nil
    end
  end

  it "rejects requiring network libraries" do
    expect(rejection_for('require "socket"')).not_to be_nil
  end

  it "explains the reason in terms the learner can act on" do
    rejection = rejection_for("def go; system('ls'); end")

    expect(rejection.reason).to include("Solve it with plain Ruby instead")
  end
end
