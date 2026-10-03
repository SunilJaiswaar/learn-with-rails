class CpuSchedulerController < ApplicationController
  before_action :require_authentication

  def show
    @algorithm = params[:algorithm].presence || "round_robin"
    @quantum = params[:quantum].to_i.clamp(1, 10)
    @quantum = 3 if @quantum.zero?

    @processes = [
      { "pid" => "P1", "burst" => 6, "priority" => 2 },
      { "pid" => "P2", "burst" => 3, "priority" => 1 },
      { "pid" => "P3", "burst" => 8, "priority" => 3 },
      { "pid" => "P4", "burst" => 2, "priority" => 4 }
    ]

    @simulation = simulate_scheduler(@algorithm, @quantum, @processes)
  end

  def simulate
    @algorithm = params[:algorithm].presence || "round_robin"
    @quantum = params[:quantum].to_i.clamp(1, 10)
    @quantum = 3 if @quantum.zero?

    @processes = [
      { "pid" => "P1", "burst" => 6, "priority" => 2 },
      { "pid" => "P2", "burst" => 3, "priority" => 1 },
      { "pid" => "P3", "burst" => 8, "priority" => 3 },
      { "pid" => "P4", "burst" => 2, "priority" => 4 }
    ]

    @simulation = simulate_scheduler(@algorithm, @quantum, @processes)

    if @algorithm == "sjf" || (@algorithm == "round_robin" && @quantum == 2)
      Gamification::XpAward.new(
        user: current_user,
        amount: 150,
        reason: "Optimized CPU Scheduling Latency in Operating Systems Lab",
        idempotency_key: "cpu-scheduler-#{@algorithm}-#{current_user.id}"
      ).call
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to cpu_scheduler_path(algorithm: @algorithm, quantum: @quantum) }
    end
  end

  private

  def simulate_scheduler(algo, quantum, processes)
    timeline = []
    current_time = 0
    waiting_times = {}
    turnaround_times = {}
    context_switches = 0

    case algo
    when "fifo"
      processes.each do |p|
        waiting_times[p["pid"]] = current_time
        start_t = current_time
        current_time += p["burst"]
        turnaround_times[p["pid"]] = current_time
        timeline << { "pid" => p["pid"], "start" => start_t, "end" => current_time, "duration" => p["burst"] }
      end
      context_switches = processes.size - 1
    when "sjf"
      sorted = processes.sort_by { |p| p["burst"] }
      sorted.each do |p|
        waiting_times[p["pid"]] = current_time
        start_t = current_time
        current_time += p["burst"]
        turnaround_times[p["pid"]] = current_time
        timeline << { "pid" => p["pid"], "start" => start_t, "end" => current_time, "duration" => p["burst"] }
      end
      context_switches = processes.size - 1
    when "priority"
      sorted = processes.sort_by { |p| p["priority"] }
      sorted.each do |p|
        waiting_times[p["pid"]] = current_time
        start_t = current_time
        current_time += p["burst"]
        turnaround_times[p["pid"]] = current_time
        timeline << { "pid" => p["pid"], "start" => start_t, "end" => current_time, "duration" => p["burst"] }
      end
      context_switches = processes.size - 1
    when "round_robin"
      remaining = processes.map { |p| { "pid" => p["pid"], "rem" => p["burst"], "total" => p["burst"] } }
      queue = remaining.dup

      until queue.empty?
        curr = queue.shift
        slice = [ curr["rem"], quantum ].min
        start_t = current_time
        current_time += slice
        curr["rem"] -= slice
        timeline << { "pid" => curr["pid"], "start" => start_t, "end" => current_time, "duration" => slice }
        context_switches += 1

        if curr["rem"].positive?
          queue << curr
        else
          turnaround_times[curr["pid"]] = current_time
          waiting_times[curr["pid"]] = current_time - curr["total"]
        end
      end
      context_switches = [ context_switches - 1, 0 ].max
    end

    avg_wait = (waiting_times.values.sum.to_f / processes.size).round(2)
    avg_turnaround = (turnaround_times.values.sum.to_f / processes.size).round(2)

    {
      "timeline" => timeline,
      "total_time" => current_time,
      "avg_wait" => avg_wait,
      "avg_turnaround" => avg_turnaround,
      "context_switches" => context_switches,
      "cpu_utilization" => 100.0
    }
  end
end
