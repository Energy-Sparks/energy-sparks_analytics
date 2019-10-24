require 'date'
module Benchmarking
  EXAMPLE_DATA = [
    # data estimate: 250 schools * 40 alerts * 6 fields * 365 * 2 years = 43 million or 80K/day
    #       date             schoolId  alert   variable  value
    [ Date.new(2019, 10, 10), 123456, 'aapd', 'flra',   1000.4 ], # floor 
    [ Date.new(2019, 10, 10), 123456, 'aapd', 'pupn',   250 ],    # pupil numbers
    [ Date.new(2019, 10, 10), 123456, 'aapd', 'name',   'Whiteways Primary' ], # school
    [ Date.new(2019, 10, 10), 123456, 'aapd', 'dedd',   2300 ],       # degree days
    [ Date.new(2019, 10, 10), 123456, 'aapd', 'urnn',   123456 ],      # urn
    [ Date.new(2019, 10, 10), 123456, 'aapd', 'arnm',   'Sheffield' ], # area
    [ Date.new(2019, 10, 10), 123456, 'anng', 'kwh ',   10000 ], # Annual gas kwh
    [ Date.new(2019, 10, 10), 123456, 'anng', 'gbp ',   1500 ],  # Annual gas £
  ]

  CHART_TABLE_CONFIG = {
    annual_gas_per_floor_area_chart: {
      name:     'Annual gas usage per pupil (temperature adjusted)',
      columns:  [
        # may support select statement like this going forward:
        #     select anng_kwh * 100.0 as 'Annual kWh' type :kwh,
        #            aapd_name as 'School name'
        # for now define columns as hash
        {   data: 'aapd_name',                                 name: 'School name', units: String },
        {   data: 'anng_kwh * 2000.0 / aapd_dedd / aapd_flra', name: 'Annual kWh/floor area (temp compensated)', units: :kwh },
      ],
      sort_by:  [1], # column 1 i.e. Annual kWh
      type: %i[chart table]
    }
  }

  # converts row database as in EXAMPLE_DATA into instance variables
  # one per row, to allow for subsequent formulaic binding/eval
  class DatabaseAsVariables
    def initialize(database)
      database.each do |row|
        promote_row_as_variable(row)
      end
    end

    def calculate(formula)
      eval(formula)
    end

    private

    def promote_row_as_variable(row)
      key = convert_row_key_to_variable_name(row)
      create_and_set_attr_reader(key, row[4])
    end

    def convert_row_key_to_variable_name(row)
      # "#{row[2]}_#{row[3]}_#{row[0].strftime('%Y%m%d')}".gsub(' ', '')
      "#{row[2]}_#{row[3]}".gsub(' ', '')
    end

    private def create_and_set_attr_reader(key, value)
      self.class.send(:attr_reader, key)
      instance_variable_set("@#{key}", value)
    end
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
      selected_schools = select_schools(@benchmark_database, school_ids)
      selected_dates = select_dates(selected_schools, [today])
      
      school_ids = all_school_ids(selected_dates) if school_ids.nil?
      school_ids.each do |school_id|
        school_database = select_schools(selected_dates, [school_id])
        school_class_database = DatabaseAsVariables.new(school_database)
        row = calculate_row(school_database, school_class_database, CHART_TABLE_CONFIG[report], today)
        results.push(row) unless row.nil?
      end
      results
    end

    private

    def calculate_row(school_database, school_class_database, report, date)
      row = []
      report[:columns].each do |column_specification|
        value = evaluate_value(school_class_database, date, column_specification)
        row.push(value)
      end
      row
    end

    def evaluate_value(school_class_database, date, column_specification)
      school_class_database.calculate(column_specification[:data])
    end

    def select_schools(benchmark_database, school_ids)
      select_column(benchmark_database, 1, school_ids)
    end

    def select_dates(benchmark_database, dates)
      select_column(benchmark_database, 0, dates)
    end

    def all_school_ids(benchmark_database)
      benchmark_database.map { |row| row[1] }.uniq
    end

    def select_column(database, column_number, where)
      return database if where.nil?
      database.select{ |row| where.include?(row[column_number]) }
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

  school_ids = nil # nil for all or an array of schools e.g. all Sheffield schools selected by user

  puts 'Results:'
  table = benchmark.run_benchmark_chart(today, :annual_gas_per_floor_area_chart, school_ids)
  puts table.inspect
end
