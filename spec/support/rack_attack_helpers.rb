# Throttling is disabled in the test environment so counters cannot leak
# between examples. These helpers turn it on for the specs that assert it.
module RackAttackHelpers
  # Rack::Attack buckets counters by wall-clock period, so a burst that
  # straddles a period boundary silently resets the count and the assertion
  # flakes. Time is frozen so every request in a burst lands in one window.
  def with_rack_attack(freeze: true)
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear

    if freeze
      freeze_time { yield }
    else
      yield
    end
  ensure
    Rack::Attack.enabled = false
    Rack::Attack.cache.store.clear
  end
end
