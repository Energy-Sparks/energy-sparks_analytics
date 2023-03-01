# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkContentEnergyPerPupil, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkContentEnergyPerPupil.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :annual_energy_costs_per_pupil,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:annual_energy_costs_per_pupil]
    )
  end

  describe 'introduction_text' do
    it 'includes text in the introduction text' do
      expect(benchmark.send(:introduction_text)).to include(
        I18n.t('analytics.benchmarking.content.annual_energy_costs_per_pupil.introduction_text_html')
      )
    end
    it 'includes caveat text in the introduction text' do
      expect(benchmark.send(:introduction_text)).to include(
        I18n.t('analytics.benchmarking.caveat_text.es_per_pupil_v_per_floor_area_html')
      )
    end
  end

  describe 'table_introduction_text' do
    it 'includes table introduction text' do
      expect(benchmark.send(:table_introduction_text)).to include(
        I18n.t('analytics.benchmarking.caveat_text.es_doesnt_have_all_meter_data_html')
      )
    end
  end
end
