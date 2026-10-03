module CodeExecution
  module Sandbox
    # A sandbox strategy receives a prepared working directory and runs the
    # harness inside it under isolation and resource limits.
    class Base
      Outcome = Struct.new(:stdout, :stderr, :exit_status, :timed_out, :runtime_ms,
                           keyword_init: true)

      def self.available?
        false
      end

      def initialize(workdir:, limits:)
        @workdir = workdir
        @limits = limits
      end

      def run(_argv)
        raise NotImplementedError
      end

      private

      attr_reader :workdir, :limits

      # Spawns a command in its own process group so a timeout can kill the
      # whole tree, not just the parent.
      def spawn_with_timeout(command, env: {}, timeout_seconds:)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        out_r, out_w = IO.pipe
        err_r, err_w = IO.pipe

        pid = Process.spawn(env, *command,
                            out: out_w, err: err_w, in: :close,
                            pgroup: true, close_others: true)
        out_w.close
        err_w.close

        stdout, stderr, timed_out = collect(pid, out_r, err_r, timeout_seconds)
        runtime_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

        Outcome.new(stdout: stdout, stderr: stderr, exit_status: @exit_status,
                    timed_out: timed_out, runtime_ms: runtime_ms)
      end

      def collect(pid, out_r, err_r, timeout_seconds)
        stdout = +""
        stderr = +""
        timed_out = false
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_seconds
        streams = [ out_r, err_r ]

        until streams.empty?
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          if remaining <= 0
            timed_out = true
            break
          end

          ready = IO.select(streams, nil, nil, [ remaining, 0.1 ].min)
          next unless ready

          ready.first.each do |io|
            chunk = begin
              io.read_nonblock(65_536)
            rescue IO::WaitReadable
              next
            rescue EOFError, Errno::EIO
              streams.delete(io)
              io.close unless io.closed?
              next
            end
            buffer = io == out_r ? stdout : stderr
            buffer << chunk if buffer.bytesize < MAX_OUTPUT_BYTES
          end
        end

        terminate(pid) if timed_out
        _, status = begin
          Process.waitpid2(pid)
        rescue Errno::ECHILD
          [ nil, nil ]
        end
        @exit_status = status&.exitstatus

        streams.each { |io| io.close unless io.closed? }
        [ out_r, err_r ].each { |io| io.close unless io.closed? }

        [ truncate(stdout), truncate(stderr), timed_out ]
      end

      MAX_OUTPUT_BYTES = 64 * 1024

      def truncate(text)
        return text if text.bytesize <= MAX_OUTPUT_BYTES

        "#{text.byteslice(0, MAX_OUTPUT_BYTES)}\n... output truncated ..."
      end

      # Kill the whole process group: a fork bomb inside the sandbox must not
      # survive its parent.
      def terminate(pid)
        Process.kill("-TERM", Process.getpgid(pid))
        sleep 0.2
        Process.kill("-KILL", Process.getpgid(pid))
      rescue Errno::ESRCH, Errno::EPERM
        nil
      end
    end
  end
end
