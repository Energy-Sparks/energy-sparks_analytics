# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentSolarPVBenefit, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentSolarPVBenefit.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :solar_pv_benefit_estimate,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:solar_pv_benefit_estimate]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Benefit of solar PV installation
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.solar_pv_benefit_estimate") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end