# Content Security Policy.
#
# The app ships no inline <script>, so scripts are restricted to self with a
# nonce for the importmap tag. Inline styles are still permitted because the
# views use style attributes for data-driven widths (meters, bars); tightening
# that is tracked as follow-up work rather than silently allowing 'unsafe-inline'
# for scripts too.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline
    policy.connect_src :self
    policy.base_uri    :self
    policy.form_action :self
    policy.frame_ancestors :none
  end

  # The importmap and Stimulus loader need a nonce on their script tags.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]

  # Report-only in development so a mistake is visible without breaking work.
  config.content_security_policy_report_only = Rails.env.development?
end
