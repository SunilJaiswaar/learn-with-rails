# Code execution backend (spec 74). `auto` picks bubblewrap when the host
# supports unprivileged user namespaces, and otherwise refuses to execute
# rather than running learner code directly in the Rails process.
Rails.application.configure do
  config.x.code_execution.sandbox = ENV.fetch("CODE_SANDBOX", "auto")
  config.x.code_execution.max_queue_seconds = 20
end
