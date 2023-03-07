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

  describe '#page' do
    it 'returns a chart name if charts are present' do
      expect(benchmark.page_name).to eq(:weekday_baseload_variation)
    end
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

  describe 'introduction_text' do
    it 'formats introduction and any caveat text as html' do
      html = benchmark.send(:introduction_text)
      expect(html).to match_html(<<~HTML)
        <p>
          A school&apos;s baseload is the power it consumes out of hours when
          the school is unoccupied.
        </p>
        <p>
          In general, with very few exceptions the baseload shouldn&apos;t
          vary between days of the week and even between weekdays and weekends.
        </p>
        <p>
          If there is a big variation it often suggests that there is an opportunity
          to reduce baseload by find out what is causing the baseload to be higher on
          certain days of the week than others, and switch off whatever is causing
          the difference.
        </p>
        <p>
          Consumers of out of hours electricity include
          <ul>
            <li>
              Equipment left on rather than being turned off, including
              photocopiers and ICT equipment
            </li>
            <li>
              ICT servers - can be inefficient, newer ones can often payback their
              capital costs in electricity savings within a few years, see our
              <a href="https://energysparks.uk/case_studies/4/link" target ="_blank">case study</a>
              on this
            </li>
            <li>
              Security lighting - this can be reduced by using PIR movement detectors
              - often better for security and by moving to more efficient LED lighting
            </li>
            <li>
              Fridges and freezers, particularly inefficient commercial kitchen appliances, which if
              replaced can provide a very short payback on investment (see
              our <a href="https://energysparks.uk/case_studies/1/link" target ="_blank">case study</a> on this).
            </li>
            <li>
              Hot water heaters and boilers left on outside school hours - installing a timer or getting
              the caretaker to switch these off when closing the school at night or on a Friday can
              make a big difference
            </li>
          </ul>
        <p>
        <p>
          This breakdown excludes electricity consumed by storage heaters and
          solar PV.
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
      expect(benchmark.send(:chart_name)).to eq(:weekday_baseload_variation)
    end
  end

  describe '#tables?' do
    it 'returns if tables are present' do
      expect(benchmark.send(:tables?)).to eq(true)
    end
  end  
end
