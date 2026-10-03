namespace :sql_sandbox do
  desc "Provision the read-only SQL playground schema, fixtures and role"
  task provision: :environment do
    SqlExecution::SandboxSchema.provision!
    puts "Provisioned #{SqlExecution::SandboxSchema::SCHEMA} " \
         "for role #{SqlExecution::SandboxSchema::ROLE}."
    puts "Tables: #{SqlExecution::Fixtures::TABLES.join(', ')}"
  end

  desc "Drop the SQL playground schema (the cluster-wide role is left in place)"
  task teardown: :environment do
    SqlExecution::SandboxSchema.teardown!
    puts "Dropped #{SqlExecution::SandboxSchema::SCHEMA}."
  end

  desc "Report whether the SQL playground is usable, and prove its isolation"
  task verify: :environment do
    unless SqlExecution::SandboxSchema.provisioned?
      abort "Not provisioned. Run rails sql_sandbox:provision"
    end

    checks = {
      "reads the fixtures" => lambda {
        r = SqlExecution::Runner.new(sql: "SELECT count(*) FROM employees",
                                     expected_rows: [ [ "8" ] ]).call
        r.passed?
      },
      "cannot read application tables" => lambda {
        r = SqlExecution::Runner.new(sql: "SELECT email FROM public.users").call
        r.status == :error
      },
      "cannot write" => lambda {
        r = SqlExecution::Runner.new(sql: "SELECT 1; DELETE FROM employees").call
        r.status == :rejected
      },
      "bounds long queries" => lambda {
        r = SqlExecution::Runner.new(sql: "SELECT count(*) FROM generate_series(1, 200000000)",
                                     timeout_ms: 300).call
        r.status == :timed_out
      }
    }

    failed = checks.reject do |label, check|
      ok = begin
        check.call
      rescue StandardError
        false
      end
      puts "#{ok ? 'OK  ' : 'FAIL'} #{label}"
      ok
    end

    abort "\nSQL playground isolation checks failed." if failed.any?
    puts "\nSQL playground verified."
  end
end
