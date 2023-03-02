# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentStorageHeaterOutOfHoursUsage, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentStorageHeaterOutOfHoursUsage.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :annual_storage_heater_out_of_hours_use,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:annual_storage_heater_out_of_hours_use]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Storage heaters used out of school hours
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.annual_storage_heater_out_of_hours_use") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
