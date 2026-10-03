require "rails_helper"

# These three areas existed as database records with no route at all: 9 worlds,
# 3 roadmaps and the technology registry were unreachable (audit U1, B1, B2,
# B5). The specs assert they are reachable *and* that they report demonstrated
# mastery rather than pages opened.
RSpec.describe "Learn navigation", type: :request do
  let(:user) { create(:user) }
  let(:world) { world_at("database-dungeon", name: "Database Dungeon") }

  before { sign_in_as(user) }

  def skill_in(world, slug:, **attrs)
    skill_at(slug, world: world, **attrs)
  end

  def version_at(technology, number, status)
    existing = technology.technology_versions.find_by(number: number)
    return existing.tap { |v| v.update!(status: status) } if existing

    create(:technology_version, technology: technology, number: number, status: status)
  end

  describe "worlds" do
    it "lists published worlds with their skill and mission counts" do
      skill_in(world, slug: "sql-basics", name: "SQL Basics")

      get worlds_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Database Dungeon")
      expect(response.body).to include(world_path("database-dungeon"))
    end

    it "hides an unpublished world" do
      world_at("unfinished", name: "Unfinished", published: false)

      get worlds_path

      expect(response.body).not_to include("Unfinished")
    end

    it "renders a world with its skills" do
      skill = skill_in(world, slug: "sql-joins", name: "SQL Joins")
      unlocked!(skill)

      get world_path("database-dungeon")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("SQL Joins")
      expect(response.body).to include(skill_path("sql-joins"))
    end

    it "404s an unpublished world rather than showing it" do
      world_at("hidden", name: "Hidden", published: false)

      get world_path("hidden")

      expect(response).to have_http_status(:not_found)
    end

    it "404s a world that does not exist" do
      get world_path("no-such-world")
      expect(response).to have_http_status(:not_found)
    end

    it "reports progress from demonstrated mastery, not from visits" do
      skill = skill_in(world, slug: "sql-basics", name: "SQL Basics")
      unlocked!(skill)

      get world_path("database-dungeon")
      expect(response.body).to include("0 developing or better")

      create(:skill_progress, user: user, skill: skill, mastery_level: :strong)

      get world_path("database-dungeon")
      expect(response.body).to include("1 developing or better")
    end

    it "shows a locked skill as locked, naming what it needs" do
      basics = skill_in(world, slug: "sql-basics", name: "SQL Basics")
      joins  = skill_in(world, slug: "sql-joins", name: "SQL Joins")
      unlocked!(basics)
      depends_on!(joins, basics)

      get world_path("database-dungeon")

      expect(response.body).to include("SQL Basics at developing mastery")
      expect(response.body).not_to include(skill_path("sql-joins"))
    end

    it "unlocks that skill once the prerequisite is demonstrated" do
      basics = skill_in(world, slug: "sql-basics", name: "SQL Basics")
      joins  = skill_in(world, slug: "sql-joins", name: "SQL Joins")
      unlocked!(basics)
      depends_on!(joins, basics)
      create(:skill_progress, user: user, skill: basics, mastery_level: :developing)

      get world_path("database-dungeon")

      expect(response.body).to include(skill_path("sql-joins"))
    end
  end

  describe "roadmaps" do
    # let! because the index spec asserts on it without referencing it.
    let!(:roadmap) do
      roadmap_at("rails-developer", name: "Rails Developer",
                 audience: "Backend engineers")
    end

    it "lists published roadmaps" do
      get roadmaps_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Rails Developer")
      expect(response.body).to include("Backend engineers")
    end

    it "renders a roadmap's steps in the path's own order" do
      first  = skill_at("sql-basics", name: "SQL Basics")
      second = skill_at("sql-joins", name: "SQL Joins")
      create(:learning_path_step, learning_path: roadmap, skill: second, position: 2)
      create(:learning_path_step, learning_path: roadmap, skill: first, position: 1,
                                  note: "Start here")

      get roadmap_path("rails-developer")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Start here")
      expect(response.body.index("SQL Basics")).to be < response.body.index("SQL Joins")
    end

    it "404s an unpublished roadmap" do
      roadmap_at("draft", name: "Draft", published: false)
      get roadmap_path("draft")
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "technologies" do
    let!(:technology) do
      technology_at("postgresql", name: "PostgreSQL", category: "database")
    end

    it "lists technologies with the version being taught" do
      version_at(technology, "17", :current)
      version_at(technology, "11", :eol)

      get technologies_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("PostgreSQL")
      expect(response.body).to include("v17")
    end

    it "marks a legacy version as not current practice" do
      version_at(technology, "11", :eol)

      get technology_path("postgresql")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Eol")
    end

    it "links out to official documentation" do
      version_at(technology, "17", :current)
        .update!(docs_url: "https://www.postgresql.org/docs/17/")

      get technology_path("postgresql")

      expect(response.body).to include("https://www.postgresql.org/docs/17/")
      expect(response.body).to include("noopener")
    end

    # Defence in depth behind TechnologyVersion's validation: a row written
    # past it must still not produce a clickable javascript: href.
    it "omits the link rather than rendering an unsafe scheme" do
      version = version_at(technology, "17", :current)
      version.update_column(:docs_url, "javascript:alert(1)")

      get technology_path("postgresql")

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("javascript:alert")
    end

    it "404s a technology that does not exist" do
      get technology_path("cobol")
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the sidebar" do
    it "links to the three newly reachable areas" do
      get dashboard_path

      expect(response.body).to include(worlds_path)
      expect(response.body).to include(roadmaps_path)
      expect(response.body).to include(technologies_path)
    end

    it "does not advertise areas that have no content yet" do
      get dashboard_path

      expect(response.body).not_to include(">Projects<")
      expect(response.body).not_to include(">AI Lab<")
    end
  end

  it "requires authentication for every new page" do
    delete logout_path

    [ worlds_path, roadmaps_path, technologies_path ].each do |path|
      get path
      expect(response).to redirect_to(login_path), "#{path} was reachable signed out"
    end
  end
end
