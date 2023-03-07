# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentHeatingPerFloorArea, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentHeatingPerFloorArea.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :annual_heating_costs_per_floor_area,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:annual_heating_costs_per_floor_area]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Annual heating cost per floor area with savings potential
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.annual_heating_costs_per_floor_area") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end