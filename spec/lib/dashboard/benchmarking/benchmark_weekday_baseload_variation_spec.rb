# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkWeekdayBaseloadVariation, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkWeekdayBaseloadVariation.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :weekday_baseload_variation,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:weekday_baseload_variation]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Weekday baseload variation
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.weekday_baseload_variation") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
