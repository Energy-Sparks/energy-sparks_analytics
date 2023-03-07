# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkElectricityOnDuringHoliday, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkElectricityOnDuringHoliday.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :electricity_consumption_during_holiday,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:electricity_consumption_during_holiday]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Electricity use during current holiday
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.electricity_consumption_during_holiday") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end