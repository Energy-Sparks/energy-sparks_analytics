# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentThermostaticControl, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentThermostaticControl.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :thermostatic_control,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:thermostatic_control]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Quality of thermostatic control
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.thermostatic_control") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
