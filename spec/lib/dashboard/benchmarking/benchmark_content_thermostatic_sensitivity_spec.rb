# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentThermostaticSensitivity, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentThermostaticSensitivity.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :thermostat_sensitivity,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:thermostat_sensitivity]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Annual saving through 1C reduction in thermostat temperature
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.thermostat_sensitivity") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
