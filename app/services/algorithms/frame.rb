module Algorithms
  # One step of an algorithm, in a shape the front-end visualiser can render
  # without knowing which algorithm produced it.
  class Frame
    attr_reader :narration, :data, :markers, :aux, :metrics

    def initialize(narration:, data: nil, markers: {}, aux: nil, metrics: {})
      @narration = narration
      @data = data
      @markers = markers
      @aux = aux
      @metrics = metrics
    end

    def as_json(*)
      {
        "narration" => narration,
        "data" => data,
        "markers" => markers.transform_keys(&:to_s),
        "aux" => aux,
        "metrics" => metrics.transform_keys(&:to_s)
      }.compact
    end
  end
end
