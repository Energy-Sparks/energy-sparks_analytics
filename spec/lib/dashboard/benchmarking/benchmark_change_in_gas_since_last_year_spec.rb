# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkChangeInGasSinceLastYear, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkChangeInGasSinceLastYear.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :change_in_gas_since_last_year,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:change_in_gas_since_last_year]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Annual change in gas use
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.change_in_gas_since_last_year") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
