# frozen_string_literal: true

module UsageBreakdown
  class Store
    attr_accessor :kwh, :pounds_sterling, :co2, :percent
    def initialize(kwh: 0.0, pounds_sterling: 0.0, co2: 0.0, percent: 0.0)
      @kwh = kwh
      @pounds_sterling = pounds_sterling
      @co2 = co2
      @percent = percent
    end
  end
end
