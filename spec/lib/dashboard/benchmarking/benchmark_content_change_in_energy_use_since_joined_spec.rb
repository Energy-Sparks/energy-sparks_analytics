# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentChangeInEnergyUseSinceJoined, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentChangeInEnergyUseSinceJoined.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :change_in_energy_use_since_joined_energy_sparks,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:change_in_energy_use_since_joined_energy_sparks]
    )
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          Change in energy use since the school joined Energy Sparks
        </h1>
      HTML
      title_html = '<h1>' + I18n.t("analytics.benchmarking.chart_table_config.change_in_energy_use_since_joined_energy_sparks") + '</h1>'
      expect(html).to match_html(title_html)
    end
  end
end
