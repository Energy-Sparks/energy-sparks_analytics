require 'date'
require 'ostruct'
require 'byebug'
module Benchmarking
  EXAMPLE_DATA = {
    Date.new(2019, 10, 10) => {
      123456 => {
        'aapd_flra' => 1000.4, # floor area
        'aapd_pupn'  =>   250 ,    # pupil numbers
        'aapd_name' => 'Whiteways Primary', # school
        'aapd_dedd' => 2300,       # degree days
        'aapd_urnn' => 123456,      # urn
        'aapd_arnm' => 'Sheffield', # area
        'anng_kwh£' => 10000, # Annual gas kwh
        'anng_gbp' => 1500   # Annual gas £
      }
    }
  }

  CHART_TABLE_CONFIG = {
    annual_gas_per_floor_area_chart: {
      name:     'Annual gas usage per pupil (temperature adjusted)',
      columns:  [
        {   data: 'aapd_name', name: 'School name', units: String },
        {   data: ->{ anng_kwh£ * 2000.0 / aapd_dedd / aapd_pupn }, name: 'Annual kWh/floor area (temp compensated)', units: :kwh },
        # above is a lambda/proc/closure. avoids parsing the string at runtime
      ],
      sort_by:  [1], # column 1 i.e. Annual kWh
      type: %i[chart table]
    }
  }

  # Open struct is given a hash on initialization and creates
  # method for each key which return the key's values
  class DatabaseRow < OpenStruct
  end

  class BenchmarkManager
    def initialize(benchmark_database = EXAMPLE_DATA)
      @benchmark_database = benchmark_database
    end

    def self.report_dates(today, report = :annual_gas_per_floor_area_chart)
      [today, today - 30, today - 364] # only today would be needed for the example
    end

    def run_benchmark_chart(today, report = :annual_gas_per_floor_area_chart, school_ids = [123456])
      results = []
      school_ids.each do |school_id|
        school_data = @benchmark_database.fetch(today){{}}.fetch(school_id)
        next unless school_data
        row  = DatabaseRow.new(school_data)
        calculated_row = calculate_row(row, CHART_TABLE_CONFIG[report])
        results.push(calculated_row) unless row.nil?
      end
      results
    end

    private

    def calculate_row(row, report)
      report[:columns].map do |column_specification|
        case column_specification[:data]
        when String then row.send(column_specification[:data])
        when Proc then row.instance_exec(&column_specification[:data]) # this calls the configs lambda as if it was inside the class of the database row, given the lambda access to all the row's variables
        else nil
        end
      end
    end

  end

  today = Date.new(2019, 10, 10)
  report = :annual_gas_per_floor_area_chart

  # ask benchmark manager which dates it needs data for, for this report
  # typically will be just 'today', but might be 'today - 364' if comparing
  # with previous year

  dates_required = BenchmarkManager.report_dates(today, report)

  # front end or analytics goes off and gets precalculated alert
  # data for all schools for given dates
  puts "Downloading data for #{dates_required}"
  data = EXAMPLE_DATA

  benchmark = BenchmarkManager.new(data)

  puts 'Results:'
  table = benchmark.run_benchmark_chart(today, :annual_gas_per_floor_area_chart)
  puts table.inspect
end
