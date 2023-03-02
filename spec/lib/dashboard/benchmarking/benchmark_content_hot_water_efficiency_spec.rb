# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentHotWaterEfficiency, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentHotWaterEfficiency.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :hot_water_efficiency,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:hot_water_efficiency]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Hot Water Efficiency
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.hot_water_efficiency") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
