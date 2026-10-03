# Throttling is disabled in the test environment so counters cannot leak
# between examples. These helpers turn it on for the specs that assert it.
module RackAttackHelpers
  def with_rack_attack
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
    yield
  ensure
    Rack::Attack.enabled = false
    Rack::Attack.cache.store.clear
  end
end
