
module Benchmarking
  class BenchmarkManager
    class DatabaseRow < OpenStruct; end

    def initialize(benchmark_database)
      @benchmark_database = benchmark_database
    end

    def self.report_dates(today, report = :annual_gas_per_floor_area_chart)
      [today] # only today would be needed for the example
    end

    def run_benchmark_chart(today, report, school_ids = [123456])
      config = self.class.chart_table_config(report)
      table = run_benchmark_table(today, report, school_ids, true)
      create_chart(config, table)
    end

    def run_benchmark_table(today, report, school_ids, chart_columns_only = false)
      results = []
      config = self.class.chart_table_config(report)
      school_ids = all_school_ids([today]) if school_ids.nil?
      last_year = today-364

      school_ids.each do |school_id|
        school_data = @benchmark_database.fetch(today){{}}.fetch(school_id)
        school_data_last_year = @benchmark_database.fetch(last_year){{}}.fetch(school_id)
        school_data.merge!(dated_attributes('_last_year', school_data_last_year))
        next unless school_data && school_data_last_year
        row  = DatabaseRow.new(school_data)
        calculated_row = calculate_row(row, config, chart_columns_only, school_id)
        results.push(calculated_row) if row_has_useful_data(calculated_row, config, chart_columns_only)
      end

      sort_table!(results, config) if config.key?(:sort_by)

      results
    end

    private

    def sort_table!(results, config)
      results.sort! do |row1, row2|
        sort_level = 0 # multi-column sort
        compare = nil
        loop do
          sort_col = config[:sort_by][sort_level]
          sort_col_type = config[:columns][sort_col][:units]
          compare = sort_compare(row1, row2, sort_col, sort_col_type)
          sort_level += 1
          break if sort_level >= config[:sort_by].length || compare != 0
        end 
        compare
      end
      results
    end

    def sort_compare(row1, row2, sort_col, sort_col_type)
      if sort_col_type == :timeofday
        time_of_day_compare(row1[sort_col], row2[sort_col])
      elsif sort_col_type == String
        row1[sort_col] <=> row2[sort_col]
      else
        row1[sort_col].to_f <=> row2[sort_col].to_f
      end
    end

    # avoid doing in TimeOfDay class as reduces performance of default
    def time_of_day_compare(tod1, tod2)
      if [tod1, tod2].count(&:nil?) == 1
        tod1.nil? ? 1 : -1
      else
        tod1 <=> tod2
      end
    end

    def row_has_useful_data(calculated_row, config, chart_columns_only)
      min_non_nulls = if chart_columns_only && config.key?(:number_non_null_columns_for_filtering_charts)
                        config[:number_non_null_columns_for_filtering_charts]
                      elsif !chart_columns_only && config.key?(:number_non_null_columns_for_filtering_tables)
                        config[:number_non_null_columns_for_filtering_tables]
                      else
                        1
                      end
      !calculated_row.nil? && calculated_row.compact.length > min_non_nulls
    end

    def create_chart(config, table)
      # need to extract 1st 2 'chart columns' from table data
      chart_columns_definitions = config[:columns].select {|column_definition| self.class.chart_column?(column_definition)}
      chart_column_numbers = config[:columns].each_with_index.map {|column_definition, index| self.class.chart_column?(column_definition) ? index : nil}
      chart_column_numbers.compact!

      data = table.map{ |row| row[chart_column_numbers[1]] }
      data.map!{|val| val.nil? ? nil : val * 100.0 } if chart_columns_definitions[1][:units] == :percent
      graph_definition = {}
      graph_definition[:title]          = config[:name]
      graph_definition[:x_axis]         = table.map{ |row| row[chart_column_numbers[0]] }
      graph_definition[:x_axis_ranges]  = nil
      graph_definition[:x_data]         = create_chart_data(config, table, chart_column_numbers, chart_columns_definitions)
      graph_definition[:chart1_type]    = :bar
      graph_definition[:chart1_subtype] = :stacked
      graph_definition[:y_axis_label]   = 'GBP'
      graph_definition[:config_name]    = 'Not set for benchmark charts'
      graph_definition
    end

    def create_chart_data(config, table, chart_column_numbers, chart_columns_definitions)
      chart_data = {}
      chart_column_numbers.each_with_index do |chart_column_number, index|
        data = table.map{ |row| row[chart_column_number] }
        series_name = chart_columns_definitions[index][:name]
        chart_data[series_name] = data
      end
      chart_data
    end

    def dated_attributes(suffix, school_data)
      school_data.transform_keys { |key| key.to_s + suffix }
    end

    def calculate_row(row, report, chart_columns_only, school_id_debug)
      report[:columns].map do |column_specification|
        next if chart_columns_only && !self.class.chart_column?(column_specification)
        calculate_value(row, column_specification, school_id_debug)
      end
    end

    def calculate_value(row, column_specification, school_id_debug)
      begin
        case column_specification[:data]
        when String then row.send(column_specification[:data])
        when Proc then row.instance_exec(&column_specification[:data]) # this calls the configs lambda as if it was inside the class of the database row, given the lambda access to all the row's variables
        else nil
        end
      rescue StandardError => e
        puts "#{e.message}: school id #{school_id_debug}"
        return nil
      end
    end

    def all_school_ids(selected_dates)
      list_of_school_ids = {}
      selected_dates.each do |date|
        school_ids = @benchmark_database[date].keys
        school_ids.each do |school_id|
          list_of_school_ids[school_id] = true
        end
      end
      list_of_school_ids.keys
    end
  end
end
