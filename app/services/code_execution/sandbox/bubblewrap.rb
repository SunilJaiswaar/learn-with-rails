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

      def self.available?
        File.executable?(BWRAP) && userns_enabled?
      end

      def self.userns_enabled?
        path = "/proc/sys/kernel/unprivileged_userns_clone"
        return true unless File.exist?(path)

        File.read(path).strip == "1"
      rescue SystemCallError
        false
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

      def command(script_name)
        argv = [ BWRAP ]

        argv += [ "--ro-bind", self.class.ruby_prefix, self.class.ruby_prefix ]
        LIBRARY_PATHS.each do |path|
          argv += [ "--ro-bind-try", path, path ]
        end

        argv += [
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
          "--setenv", "SBX_NPROC", limits.max_processes.to_s,
          RbConfig.ruby,
          "--disable-gems",
          File.join(WORK_MOUNT, Harness::FILENAME),
          script_name
        ]
        argv
      end
    end
  end
end
