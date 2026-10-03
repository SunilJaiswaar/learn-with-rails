# The algorithm visualiser (spec 7). Traces are computed server-side by the
# real algorithm, then stepped through in the browser.
class AlgorithmsController < ApplicationController
  MAX_INPUT_VALUES = 24

  def index
    @algorithms = Algorithm.includes(:skill).ordered.group_by(&:category)
  end

  def show
    @algorithm = Algorithm.includes(:skill, :topic).find_by_slug!(params[:id])
    @input = parsed_input || @algorithm.default_input
    @frames = @algorithm.trace(@input).map(&:as_json)
    @traceable = Algorithms::Tracer.supports?(@algorithm.slug)
    @challenges = @algorithm.skill&.challenges&.published&.order(:difficulty)&.limit(4) || []
  end

  # Re-traces with learner-supplied input without a full page load.
  def trace
    @algorithm = Algorithm.find_by_slug!(params[:id])
    frames = @algorithm.trace(parsed_input || @algorithm.default_input).map(&:as_json)
    render json: { frames: frames }
  end

  private

  # Input comes from the learner, so it is parsed strictly and capped.
  def parsed_input
    raw = params[:input].to_s
    return nil if raw.blank?

    values = raw.split(/[,\s]+/).reject(&:blank?).first(MAX_INPUT_VALUES)
    numbers = values.filter_map { |v| Integer(v, exception: false) }
    numbers.presence
  end
end
