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

  describe '#page' do
    it 'returns a chart name if charts are present' do
      expect(benchmark.page_name).to eq(:electricity_peak_kw_per_pupil)
    end
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

  describe 'introduction_text' do
    it 'formats introduction and any caveat text as html' do
      html = benchmark.send(:introduction_text)
      expect(html).to match_html(<<~HTML)
        <p>
          This comparison shows the peak daily school power consumption per floor area.
          High values compared with other schools might suggest inefficient lighting,
          appliances or kitchen equipment. The peaks generally occur during the middle
          of the day. Energy Sparks allows you to drill down to individual school day usage
          to better understand the intraday characteristics of a school&apos;s electricity
          consumption.
        </p>
        <p>
          If a school&apos;s electricity consumption is high compared with
          other schools is probably warrants further investigation. There might be
          simple low-cost remedies like turning lighting off when it is bright outside,
          or better management of appliances in a school&apos;s kitchen. Other measures
          like installing LED lighting might require investment.
        </p>
        <p>
          LED lighting for example can consume as little as 4W/m<sup>2</sup>, whereas older
          less efficient lighting can consume up to 12W/m<sup>2</sup>.
        </p>
      HTML
      # content_html = '<p>' + 
      #   I18n.t('analytics.benchmarking.content.annual_energy_costs_per_floor_area.introduction_text_html') +
      #   I18n.t('analytics.benchmarking.caveat_text.es_per_pupil_v_per_floor_area_useful_html') + '</p>'
      # expect(html).to match_html(content_html)
    end
  end

  describe '#table_interpretation_text' do
    it 'formats table interpretation text as html' do
      html = benchmark.send(:table_interpretation_text)
      expect(html).to match_html(<<~HTML)
      HTML
    end
  end

  describe '#caveat_text' do
    it 'formats caveat text as html' do
      html = benchmark.send(:caveat_text)
      expect(html).to match_html(<<~HTML)
      HTML
    end
  end

  describe '#charts?' do
    it 'returns if charts are present' do
      expect(benchmark.send(:charts?)).to eq(true)
    end
  end

  describe '#chart_name' do
    it 'returns a chart name if charts are present' do
      expect(benchmark.send(:chart_name)).to eq(:electricity_peak_kw_per_pupil)
    end
  end

  describe '#tables?' do
    it 'returns if tables are present' do
      expect(benchmark.send(:tables?)).to eq(true)
    end
  end  
end
