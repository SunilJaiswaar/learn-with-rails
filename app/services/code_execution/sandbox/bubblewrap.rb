module CodeExecution
  module Sandbox
    # Isolation via bubblewrap (bwrap) using unprivileged user namespaces:
    #
    #   * --unshare-all       no network, no pid/ipc/uts sharing with the host
    #   * --ro-bind / /       the host filesystem is visible but read-only
    #   * --bind work /tmp/work  the only writable path
    #   * --die-with-parent   orphaned sandboxes cannot outlive the runner
    #   * --new-session       detaches the controlling terminal (no TIOCSTI)
    #
    # CPU, address space, file size and process count limits are applied by the
    # in-sandbox harness, because setting RLIMIT_NPROC on the bwrap process
    # itself makes namespace creation fail with EAGAIN.
    class Bubblewrap < Base
      BWRAP = "/usr/bin/bwrap"
      WORK_MOUNT = "/tmp/work"

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

      def run(script_name)
        command = [
          BWRAP,
          "--ro-bind", "/", "/",
          "--dev", "/dev",
          "--proc", "/proc",
          "--tmpfs", "/tmp",
          "--bind", workdir.to_s, WORK_MOUNT,
          "--chdir", WORK_MOUNT,
          "--unshare-all",
          "--die-with-parent",
          "--new-session",
          "--setenv", "HOME", WORK_MOUNT,
          "--setenv", "TMPDIR", WORK_MOUNT,
          RbConfig.ruby,
          "--disable-gems",
          File.join(WORK_MOUNT, Harness::FILENAME),
          script_name
        ]

        spawn_with_timeout(
          command,
          env: harness_env,
          # Wall-clock budget sits above the CPU limit so a sleeping process is
          # still reaped, with a small margin for interpreter startup.
          timeout_seconds: (limits.cpu_seconds + limits.wall_margin_seconds)
        )
      end

      private

      def harness_env
        {
          "SBX_CPU" => limits.cpu_seconds.to_s,
          "SBX_AS" => limits.address_space_bytes.to_s,
          "SBX_FSIZE" => limits.file_size_bytes.to_s,
          "SBX_NPROC" => limits.max_processes.to_s,
          "RUBYOPT" => ""
        }
      end
    end
  end
end
