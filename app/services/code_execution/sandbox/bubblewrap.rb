require "open3"
require "tmpdir"

module CodeExecution
  module Sandbox
    # Isolation via bubblewrap (bwrap) using unprivileged user namespaces.
    #
    # The mount set is an allow-list, not the whole host: only the Ruby
    # installation and the shared libraries it links against are visible, so
    # learner code cannot read application source, credentials or /etc.
    # The single writable path is the per-run working directory.
    #
    #   --unshare-all      no network, and no shared pid/ipc/uts namespaces
    #   --die-with-parent  an orphaned sandbox cannot outlive the runner
    #   --new-session      detaches the controlling tty (blocks TIOCSTI tricks)
    # The sandbox inherits none of the server's environment: the bwrap process
    # itself is spawned with a cleared env (bwrap 0.4 has no --clearenv), and
    # only the limit variables are injected with --setenv.
    #
    # CPU, address-space, file-size and process limits are applied by the
    # in-sandbox harness: setting RLIMIT_NPROC on the bwrap process itself
    # makes user-namespace creation fail with EAGAIN.
    class Bubblewrap < Base
      BWRAP = "/usr/bin/bwrap"
      WORK_MOUNT = "/tmp/work"

      # Directories holding the shared objects the interpreter links against.
      LIBRARY_PATHS = %w[/lib /lib64 /usr/lib /usr/lib64].freeze

      # Availability is established by *running* the sandbox once, not by
      # inspecting kernel flags.
      #
      # Guessing from /proc/sys/kernel/unprivileged_userns_clone is wrong twice
      # over: the file does not exist on newer kernels (so its absence says
      # nothing), and even where user namespaces are permitted, bwrap can still
      # fail to configure loopback inside the new network namespace — which is
      # what happens on hosts that deny CAP_NET_ADMIN there. A probe catches
      # both, so the specs skip honestly instead of reporting the security
      # boundary as working when it is not.
      def self.available?
        return @available if defined?(@available)

        @available = File.executable?(BWRAP) && probe_succeeds?
      end

      def self.reset_availability!
        remove_instance_variable(:@available) if defined?(@available)
      end

      # Runs the smallest possible program through the real sandbox flags.
      def self.probe_succeeds?
        probe = probe_result
        probe[:ok]
      end

      # Exposed so operators get the actual reason, not just a boolean.
      def self.probe_result
        Dir.mktmpdir("codequest-probe-") do |dir|
          workdir = Pathname(dir)
          workdir.join("probe.rb").write("print 1\n")

          limits = Limits.default
          outcome = new(workdir: workdir, limits: limits).send(:probe, "probe.rb")

          if outcome[:status]&.success? && outcome[:stdout] == "1"
            { ok: true, reason: nil }
          else
            { ok: false, reason: outcome[:stderr].to_s.strip.presence ||
                                 "bwrap exited #{outcome[:status]&.exitstatus.inspect}" }
          end
        end
      rescue StandardError => e
        { ok: false, reason: "#{e.class}: #{e.message}" }
      end

      # Only the interpreter's own prefix is exposed, never its parent dirs.
      def self.ruby_prefix
        RbConfig::CONFIG.fetch("prefix")
      end

      def run(script_name)
        spawn_with_timeout(
          command(script_name),
          env: {},
          # The wall-clock budget sits above the CPU limit so that a sleeping
          # (not spinning) process is still reaped.
          timeout_seconds: limits.cpu_seconds + limits.wall_margin_seconds
        )
      end

      private

      # Deliberately bypasses the harness so the probe tests the sandbox itself.
      def probe(script_name)
        argv = command_prefix + [ RbConfig.ruby, "--disable-gems",
                                  File.join(WORK_MOUNT, script_name) ]
        stdout, stderr, status = Open3.capture3({}, *argv, unsetenv_others: true)
        { stdout: stdout, stderr: stderr, status: status }
      end

      def command(script_name)
        command_prefix + [
          RbConfig.ruby,
          "--disable-gems",
          File.join(WORK_MOUNT, Harness::FILENAME),
          script_name
        ]
      end

      # The isolation flags, shared by real runs and the availability probe so
      # the probe cannot pass under weaker settings than production uses.
      def command_prefix
        argv = [ BWRAP, "--ro-bind", self.class.ruby_prefix, self.class.ruby_prefix ]

        LIBRARY_PATHS.each { |path| argv += [ "--ro-bind-try", path, path ] }

        argv + [
          "--proc", "/proc",
          "--dev", "/dev",
          "--tmpfs", "/tmp",
          "--bind", workdir.to_s, WORK_MOUNT,
          "--chdir", WORK_MOUNT,
          "--unshare-all",
          "--die-with-parent",
          "--new-session",
          "--setenv", "HOME", WORK_MOUNT,
          "--setenv", "TMPDIR", WORK_MOUNT,
          "--setenv", "SBX_CPU", limits.cpu_seconds.to_s,
          "--setenv", "SBX_AS", limits.address_space_bytes.to_s,
          "--setenv", "SBX_FSIZE", limits.file_size_bytes.to_s,
          "--setenv", "SBX_NPROC", limits.max_processes.to_s
        ]
      end
    end
  end
end
