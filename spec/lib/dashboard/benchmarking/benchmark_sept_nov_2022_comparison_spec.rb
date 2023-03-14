# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext'

describe Benchmarking::BenchmarkSeptNov2022Comparison, type: :service do
  let(:benchmark) do
    Benchmarking::BenchmarkSeptNov2022Comparison.new(
      benchmark_database_hash,
      benchmark_database_hash.keys.first,
      :sept_nov_2021_2022_energy_comparison,
      Benchmarking::BenchmarkManager::CHART_TABLE_CONFIG[:sept_nov_2021_2022_energy_comparison]
    )
  end

  describe '#page' do
    it 'returns a chart name if charts are present' do
      expect(benchmark.page_name).to eq(:sept_nov_2021_2022_energy_comparison)
    end
  end

  describe '#content_title' do
    it 'returns the content title' do
      html = benchmark.send(:content_title)
      expect(html).to match_html(<<~HTML)
        <h1>
          September to November 2021 versus 2022 energy use
        </h1>
      HTML
      title_html = "<h1>#{I18n.t('analytics.benchmarking.chart_table_config.sept_nov_2021_2022_energy_comparison')}</h1>"
      expect(html).to match_html(title_html)
    end
  end

  describe 'introduction_text' do
    it 'formats introduction and any caveat text as html' do
      # Inherits from BenchmarkChangeAdhocComparison
      html = benchmark.send(:introduction_text)
      expect(html).to match_html(<<~HTML)
        <p>
          This comparison below for gas and storage heaters has the
          the previous period temperature compensated to the current
          period's temperatures.
        </p>
        <p>
          Schools' solar PV production has been removed from the comparison.
        </p>
        <p>
          CO2 values for electricity (including where the CO2 is
          aggregated across electricity, gas, storage heaters) is difficult
          to compare for short periods as it is dependent on the carbon intensity
          of the national grid on the days being compared and this could vary by up to
          300&percnt; from day to day.
        </p>      
      HTML
    end
  end

  describe '#table_interpretation_text' do
    it 'formats table interpretation text as html' do
      html = benchmark.send(:table_interpretation_text)
      expect(html).to match_html(<<~HTML)
      HTML
    end
  end

  describe '#table_introduction_text' do
    it 'formats table introduction text as html' do
      html = benchmark.send(:table_introduction_text)
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
      expect(benchmark.send(:chart_name)).to eq(:sept_nov_2021_2022_energy_comparison)
    end
  end

  describe '#tables?' do
    it 'returns if tables are present' do
      expect(benchmark.send(:tables?)).to eq(true)
    end
  end

  describe '#column_heading_explanation' do
    it 'returns the benchmark column_heading_explanation' do
      html = benchmark.column_heading_explanation
      expect(html).to match_html(<<~HTML)
        <p>
          In school comparisons &apos;last year&apos; is defined as this year to date, &apos;previous year&apos; is defined as the year before.
        </p>
      HTML
    end
  end

  describe 'footnote' do
    it 'returns footnote text' do
      content = benchmark.send(:footnote, [795, 629, 634], nil, {})
      expect(content).to match_html('')
    end
  end

  describe 'content' do
    it 'creates a content array' do
      content = benchmark.content(school_ids: [795, 629, 634], filter: nil)
      expect(content.class).to eq(Array)
      expect(content.size).to be > 0
    end

    it 'translates column_groups' do
      content = benchmark.content(school_ids: [795, 629, 634], filter: nil)
      column_groups = content.select { |c| c[:type] == :table_composite }.map { |c| c.dig(:content, :column_groups) }.compact
      expect(column_groups).to eq(
        [
          [
            {:name=>"", :span=>1},
            {:name=>"kWh", :span=>3},
            {:name=>"CO2 (kg)", :span=>3},
            {:name=>"Cost", :span=>3},
            {:name=>"", :span=>1}
          ],
          [
            {:name=>"", :span=>1},
            {:name=>"kWh", :span=>3},
            {:name=>"CO2 (kg)", :span=>3},
            {:name=>"Cost", :span=>3}
          ],
          [
            {:name=>"", :span=>1},
            {:name=>"kWh", :span=>4},
            {:name=>"CO2 (kg)", :span=>3},
            {:name=>"Cost", :span=>3}
          ]
        ]
      )
    end
  end
end
