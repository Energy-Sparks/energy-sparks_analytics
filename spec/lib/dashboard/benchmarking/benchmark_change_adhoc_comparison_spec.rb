# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkChangeAdhocComparison, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkChangeAdhocComparison.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :layer_up_powerdown_day_november_2022,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:layer_up_powerdown_day_november_2022]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Change in energy for layer up power down day 11 November 2022 (compared with 12 Nov 2021)
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.layer_up_powerdown_day_november_2022") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
