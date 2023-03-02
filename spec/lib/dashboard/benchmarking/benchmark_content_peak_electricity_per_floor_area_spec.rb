# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentPeakElectricityPerFloorArea, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentPeakElectricityPerFloorArea.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :electricity_peak_kw_per_pupil,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:electricity_peak_kw_per_pupil]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Peak school day electricity use
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.electricity_peak_kw_per_pupil") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
