module Baseload
  class SeasonalVariation
    attr_reader :metric_id, :summer_kw, :winter_kw, :percentage

    def initialize(metric_id: :seasonal_baseload_variation, varsummer_kw:, winter_kw:, percentage:)
      @summer_kw = summer_kw
      @winter_kw = winter_kw
      @percentage = percentage
    end
  end
end
