class ApplicationJob < ActiveJob::Base
  # A deadlock is transient; retrying beats failing the whole run.
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3

  # A record deleted between enqueue and perform is not an error worth paging on.
  discard_on ActiveJob::DeserializationError
end
