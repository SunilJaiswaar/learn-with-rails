require "rails_helper"

RSpec.describe RailsLab::Pipeline do
  def trace(**args)
    described_class.new(**args).call
  end

  describe "a request that succeeds" do
    subject(:result) { trace(verb: "GET", path: "/skills/sql-joins") }

    it "reaches every stage" do
      expect(result).to be_completed
      expect(result.stages.map(&:key)).to eq(described_class::STAGES)
    end

    it "answers 200" do
      expect(result.status).to eq(200)
    end

    it "has nothing to blame" do
      expect(result.stopped_at).to be_nil
      expect(result.because).to be_nil
    end

    it "sums only the stages that ran" do
      expect(result.total_ms).to eq(result.stages.sum(&:timing_ms))
    end
  end

  describe "params assembly" do
    it "derives controller and action from the path" do
      params = trace(path: "/skills/sql-joins").params
      expect(params["controller"]).to eq("skills")
      expect(params["action"]).to eq("show")
      expect(params["id"]).to eq("sql-joins")
    end

    it "uses index for a collection path" do
      expect(trace(path: "/skills").params["action"]).to eq("index")
    end

    it "uses create for a POST" do
      expect(trace(verb: "POST", path: "/skills").params["action"]).to eq("create")
    end

    it "merges the query string in, which is the lesson" do
      params = trace(path: "/skills", query: "?page=2&sort=name").params
      expect(params["page"]).to eq("2")
      expect(params["sort"]).to eq("name")
    end

    it "lets the query string overwrite a route segment, as Rails does" do
      params = trace(path: "/skills/real", query: "?id=injected").params
      expect(params["id"]).to eq("injected")
    end

    it "falls back to home for the root path" do
      expect(trace(path: "/").params["controller"]).to eq("home")
    end
  end

  describe "each failure stops at the right layer" do
    {
      "unknown_path" => { stage: :router, status: 404 },
      "missing_csrf" => { stage: :controller, status: 422 },
      "record_not_found" => { stage: :model, status: 404 },
      "throttled" => { stage: :middleware, status: 429 },
      "not_authenticated" => { stage: :controller, status: 302 }
    }.each do |condition, expected|
      it "#{condition} stops at #{expected[:stage]} with #{expected[:status]}" do
        result = trace(condition: condition)

        expect(result.status).to eq(expected[:status])
        expect(result.stopped_at).to be_present
        expect(result.stages.select(&:reached?).last.key).to eq(expected[:stage])
      end

      it "#{condition} explains itself" do
        expect(trace(condition: condition).because).to be_present
      end
    end

    it "runs no stage after the halt" do
      result = trace(condition: "throttled")
      reached = result.stages.select(&:reached?).map(&:key)

      expect(reached).to eq(%i[web_server middleware])
      expect(result.stages.reject(&:reached?).map(&:key))
        .to eq(%i[router controller model database view response])
    end

    it "charges no time to a stage that never ran" do
      result = trace(condition: "unknown_path")
      expect(result.stages.reject(&:reached?).sum(&:timing_ms)).to be_zero
    end
  end

  describe "the slow query, which stops nothing" do
    subject(:result) { trace(condition: "slow_query") }

    it "completes every stage" do
      expect(result).to be_completed
    end

    it "still answers 200, which is why it hides" do
      expect(result.status).to eq(200)
    end

    it "spends its time in the database" do
      database = result.stages.find { |stage| stage.key == :database }
      expect(database.timing_ms).to eq(1_400)
      expect(result.total_ms).to be > 1_400
    end
  end

  it "ignores a condition it does not know rather than inventing one" do
    result = trace(condition: "made_up")
    expect(result).to be_completed
    expect(result.condition).to be_nil
  end

  it "treats a blank path as the root" do
    expect(trace(path: "").path).to eq("/")
  end

  it "reports the middleware count from the real stack" do
    middleware = trace.stages.find { |stage| stage.key == :middleware }
    expect(middleware.name).to include(RailsLab::MiddlewareStack.count.to_s)
  end
end
