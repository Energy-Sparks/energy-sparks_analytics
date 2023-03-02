# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkGasHeatingHotWaterOnDuringHoliday, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkGasHeatingHotWaterOnDuringHoliday.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :gas_consumption_during_holiday,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:gas_consumption_during_holiday]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Gas use during current holiday
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.gas_consumption_during_holiday") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
