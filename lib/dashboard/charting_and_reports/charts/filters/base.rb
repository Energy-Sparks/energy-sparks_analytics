# frozen_string_literal: true

require_relative '../aggregator_config.rb'

module Charts
  # filters can be applied either pre or post calculation depending on expedience/performance
  # so pre-filters determine in advice whether something needs calculating and then don't calculate
  # post-filters - do the calculation and then removes results before passing back fro display
  module Filters
    class Base
      include Logging

      def initialize(school, chart_config, results)
        @school       = school
        @chart_config = AggregatorConfig.new(chart_config)
        @results      = results
      end
    end
  end
end
