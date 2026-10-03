class GitLabController < ApplicationController
  before_action :require_authentication

  def show
    session[:git_state] ||= default_git_state
    @state = session[:git_state]
  end

  def execute_command
    session[:git_state] ||= default_git_state
    raw_cmd = params[:command].to_s.strip
    output = ""

    case raw_cmd
    when "git status"
      staged = session[:git_state]["staging"]
      working = session[:git_state]["working_tree"]
      output = "On branch #{session[:git_state]['current_branch']}\n"
      if staged.any?
        output += "Changes to be committed:\n  (use \"git restore --staged <file>...\" to unstage)\n"
        staged.each { |f| output += "\t\e[32mmodified:   #{f}\e[0m\n" }
      end
      if working.any?
        output += "Changes not staged for commit:\n"
        working.each { |f| output += "\t\e[31mmodified:   #{f}\e[0m\n" }
      end
      output += "nothing to commit, working tree clean\n" if staged.empty? && working.empty?
    when /^git add (.+)$/
      file = Regexp.last_match(1).strip
      if file == "." || file == "-A"
        session[:git_state]["staging"].concat(session[:git_state]["working_tree"]).uniq!
        session[:git_state]["working_tree"] = []
      elsif session[:git_state]["working_tree"].include?(file)
        session[:git_state]["working_tree"].delete(file)
        session[:git_state]["staging"] << file unless session[:git_state]["staging"].include?(file)
      end
      output = "Staged changes for commit."
    when /^git commit -m ["'](.+)["']$/
      msg = Regexp.last_match(1).strip
      if session[:git_state]["staging"].empty?
        output = "nothing to commit, working tree clean"
      else
        sha = SecureRandom.hex(3)
        parent_sha = session[:git_state]["branches"][session[:git_state]["current_branch"]]
        new_commit = {
          "sha" => sha,
          "parent" => parent_sha,
          "message" => msg,
          "author" => current_user.name
        }
        session[:git_state]["commits"] << new_commit
        session[:git_state]["branches"][session[:git_state]["current_branch"]] = sha
        session[:git_state]["staging"] = []
        output = "[#{session[:git_state]['current_branch']} #{sha}] #{msg}\n #{new_commit['sha']} changed"
      end
    when /^git branch ([a-zA-Z0-9_\-]+)$/
      branch_name = Regexp.last_match(1).strip
      current_sha = session[:git_state]["branches"][session[:git_state]["current_branch"]]
      session[:git_state]["branches"][branch_name] = current_sha
      output = "Created branch #{branch_name} at #{current_sha}."
    when /^git checkout ([a-zA-Z0-9_\-]+)$/, /^git switch ([a-zA-Z0-9_\-]+)$/
      branch_name = Regexp.last_match(1).strip
      if session[:git_state]["branches"].key?(branch_name)
        session[:git_state]["current_branch"] = branch_name
        output = "Switched to branch '#{branch_name}'"
      else
        output = "error: pathspec '#{branch_name}' did not match any file(s) known to git"
      end
    when "git merge feature/auth"
      if session[:git_state]["current_branch"] == "main"
        session[:git_state]["conflict_active"] = true
        output = "Auto-merging app/models/user.rb\nCONFLICT (content): Merge conflict in app/models/user.rb\nAutomatic merge failed; fix conflicts and then commit the result."
      else
        output = "Already up to date."
      end
    when "git log", "git log --oneline"
      output = session[:git_state]["commits"].reverse.map { |c| "#{c['sha']} (#{c['message']})" }.join("\n")
    else
      output = "git: '#{raw_cmd}' is not a recognized command in this simulator. Try 'git status', 'git add .', 'git commit -m \"...\"', 'git branch <name>', 'git checkout <name>', 'git merge feature/auth'."
    end

    @last_output = output
    @state = session[:git_state]

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to git_lab_path }
    end
  end

  def resolve_conflict
    session[:git_state] ||= default_git_state
    resolved_code = params[:resolved_code].to_s

    # Checks if conflict markers are removed
    if !resolved_code.include?("<<<<<<<") && !resolved_code.include?("=======") && !resolved_code.include?(">>>>>>>") && resolved_code.include?("has_secure_password")
      session[:git_state]["conflict_active"] = false
      sha = SecureRandom.hex(3)
      session[:git_state]["commits"] << {
        "sha" => sha,
        "parent" => session[:git_state]["branches"]["main"],
        "message" => "Merge branch 'feature/auth' into main (resolved conflicts)",
        "author" => current_user.name
      }
      session[:git_state]["branches"]["main"] = sha

      Gamification::XpAward.new(
        user: current_user,
        amount: 150,
        reason: "Resolved Git Merge Conflict in Git Time Machine",
        idempotency_key: "git-merge-conflict-#{current_user.id}"
      ).call

      flash[:notice] = "Merge conflict resolved cleanly! Commit #{sha} created (+150 XP)."
    else
      flash[:alert] = "Conflict markers still present or required authentication logic missing. Inspect diff and clean conflict delimiters."
    end

    redirect_to git_lab_path
  end

  def reset
    session[:git_state] = default_git_state
    redirect_to git_lab_path, notice: "Git Time Machine reset to initial repository state."
  end

  private

  def default_git_state
    {
      "current_branch" => "main",
      "working_tree" => [ "app/models/user.rb" ],
      "staging" => [],
      "branches" => {
        "main" => "a1b2c3",
        "feature/auth" => "d4e5f6"
      },
      "commits" => [
        { "sha" => "9901aa", "parent" => nil, "message" => "Initial repository setup", "author" => "Dev" },
        { "sha" => "a1b2c3", "parent" => "9901aa", "message" => "Add database migrations and schema", "author" => "Dev" },
        { "sha" => "d4e5f6", "parent" => "a1b2c3", "message" => "Add OAuth authentication provider", "author" => "Alice" }
      ],
      "conflict_active" => false
    }
  end
end
