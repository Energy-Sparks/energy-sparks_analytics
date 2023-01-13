# frozen_string_literal: true

module UsageBreakdown
  class Store
    attr_accessor :kwh, :pounds_sterling, :co2, :percent
    def initialize(kwh: nil, pounds_sterling: nil, co2: nil, percent: nil)
      @kwh = kwh
      @pounds_sterling = pounds_sterling
      @co2 = co2
      @percent = percent
    end
  end
end
