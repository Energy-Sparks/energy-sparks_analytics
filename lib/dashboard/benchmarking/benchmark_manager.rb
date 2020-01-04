
module Benchmarking
  class BenchmarkManager
    include Logging
    class DatabaseRow < OpenStruct
      def zero(value)BenchmarkManager
        value.nil? ? 0.0 : value
      end

      def percent_change(base, new_val, to_nil_if_sum_zero = false)
        return 0.0 if sum_data(base) == 0.0
        change = (sum_data(new_val) - sum_data(base)) / sum_data(base)
        (to_nil_if_sum_zero && change == 0.0) ? nil : change
      end

      def or_nil(arr)
        arr.compact.empty? ? nil : arr.compact[0]
      end

      def sum_data(data, to_nil_if_sum_zero = false)
        data = [data] unless data.is_a?(Array)
        data.map! { |value| zero(value) } # create array 1st to avoid statsample map/sum bug
        val = data.sum
        (to_nil_if_sum_zero && val == 0.0) ? nil : val
      end

      def area
        addp_area.nil? ? '?' : addp_area.split(' ')[0]
      end

      def school_name
        addp_name
      end
    end

    attr_reader :benchmark_database

    def initialize(benchmark_database)
      @benchmark_database = benchmark_database
    end

    def self.report_dates(today, report = :annual_gas_per_floor_area_chart)
      [today] # only today would be needed for the example
    end

    def run_benchmark_chart(today, report, school_ids, chart_columns_only = false, filter = nil, user_type = nil)
      config = self.class.chart_table_config(report)
      table = run_benchmark_table(today, report, school_ids, chart_columns_only, filter, user_type)
      create_chart(report, config, table)
    end

    # filter e.g. for area: ->{ addp_area.include?('Highlands') }
    def run_benchmark_table(today, report, school_ids, chart_columns_only = false, filter = nil, medium = :raw, user_type)
      results = []
      full_config = self.class.chart_table_config(report)
      config = hide_columns(full_config, user_type)
      school_ids = all_school_ids([today]) if school_ids.nil?
      last_year = today - 364

      school_ids.each do |school_id|
        school_data = @benchmark_database.fetch(today){{}}.fetch(school_id)
        school_data_last_year = @benchmark_database.fetch(last_year){{}}.fetch(school_id)
        school_data.merge!(dated_attributes('_last_year', school_data_last_year))
        next unless school_data && school_data_last_year
        row  = DatabaseRow.new(school_data)
        next unless filter_row(row, filter)
        calculated_row = calculate_row(row, config, chart_columns_only, school_id)
        results.push(calculated_row) if row_has_useful_data(calculated_row, config, chart_columns_only)
      end

      sort_table!(results, config) if config.key?(:sort_by)

      format_table(config, results, medium)
    end

    private
    
    def hide_columns(config, user_type)
      new_config = config.clone
      new_config[:columns].delete_if do |column|
        rating_column?(column) && !ContentBase.system_admin_type?(user_type)
      end
      new_config
    end

    def sort_table!(results, config)
      if config[:sort_by].is_a?(Array)
        sort_table_by_column!(results, config)
      elsif config[:sort_by].is_a?(Method)
        results.sort! { |a, b| config[:sort_by].call(a, b) }
      end
    end

    def sort_table_by_column!(results, config)
      results.sort! do |row1, row2|
        sort_level = 0 # multi-column sort
        compare = nil
        loop do
          reverse_it = false
          sort_col = config[:sort_by][sort_level]
          if sort_col.is_a?(Hash)
            reverse_it = true
            sort_col = sort_col.values[0]
          end
          sort_col_type = config[:columns][sort_col][:units]
          compare = sort_compare(row1, row2, sort_col, sort_col_type)
          compare *= -1 unless reverse_it
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

    def format_table(table_definition, rows, medium)
      header = table_definition[:columns].map{ |column_definition| column_definition[:name] }
      case medium
      when :raw
        [header] + rows
      when :text, :text_and_raw
        formatted_rows = format_rows(rows, table_definition[:columns], medium)
        {header: header, rows: formatted_rows}
      when :html
        formatted_rows = format_rows(rows, table_definition[:columns], medium)
        HtmlTableFormatting.new(header, formatted_rows).html
      end
    end

    def format_rows(rows, column_definitions, medium)
      column_units = column_definitions.map{ |column_definition| column_definition[:units] }
      column_sense = column_definitions.map{ |column_definition| column_definition.dig(:sense) }
      
      formatted_rows = rows.map do |row|
        row.each_with_index.map do |value, index|
          sense = sense_column(column_sense[index])
          if column_units[index] == String
            format_cell_string(value, medium, sense)
          else
            format_cell(column_units[index], value, medium, sense)
          end
        end
      end
    end

    def sense_column(sense)
      sense.nil? ? nil : { sense: sense }
    end

    def format_cell_string(value, medium, sense)
      if medium == :text_and_raw
        data = {
          formatted: value,
          raw: value,
        }
        data.merge!(sense) unless sense.nil?
        data
      else
        value
      end
    end
    
    def format_cell(units, value, medium, sense)
      if medium == :text_and_raw
        data = {
          formatted: format_cell(units, value, :text, nil),
          raw: value
        }
        data.merge!(sense) unless sense.nil?
        data
      else
        FormatEnergyUnit.format(units, value, medium, false, true, :benchmark)
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
                      else
                        1 + (self.class.y2_axis_column?(config) ? 1 : 0)
                      end
      !calculated_row.nil? && calculated_row.compact.length > min_non_nulls
    end

    def create_chart(chart_name, config, table, include_y2 = false)
      # need to extract 1st 2 'chart columns' from table data
      chart_columns_definitions = config[:columns].select {|column_definition| self.class.chart_column?(column_definition)}
      chart_column_numbers = config[:columns].each_with_index.map {|column_definition, index| self.class.chart_column?(column_definition) ? index : nil}
      chart_column_numbers.compact!

      graph_definition = {}
      graph_definition[:title]          = config[:name]
      graph_definition[:x_axis]         = remove_first_column(table.map{ |row| row[chart_column_numbers[0]] })
      graph_definition[:x_axis_ranges]  = nil
      graph_definition[:x_data]         = create_chart_data(config, table, chart_column_numbers, chart_columns_definitions)
      graph_definition[:chart1_type]    = :bar
      graph_definition[:chart1_subtype] = :stacked
      graph_definition[:y_axis_label]   = y_axis_label(chart_columns_definitions)
      graph_definition[:config_name]    = chart_name.to_s

      y2_data = create_y2_data(config, table, chart_column_numbers, chart_columns_definitions)

      unless y2_data.empty? || !include_y2
        graph_definition[:y2_data] = y2_data
        graph_definition[:y2_chart_type] = :line
      end

      graph_definition
    end

    def y_axis_type(chart_columns_definitions)
      first_chart_data_column = chart_columns_definitions[1] # [0] = school name
      first_chart_data_column[:units]
    end

    def y_axis_label(chart_columns_definitions)
      y_axis_label_name(y_axis_type(chart_columns_definitions))
    end

    def y_axis_label_name(unit)
      unit_names = { kwh: 'kWh', kw: 'kW', co2: 'kg CO2', £: '£', w: 'W', £_0dp: '£',
                     timeofday: 'Time of day',
                     percent: 'percent', percent_0dp: 'percent',
                     relative_percent: 'percent', relative_percent_0dp: 'percent',
                     days: 'days' }
      return unit_names[unit] if unit_names.key?(unit)
      logger.info "Unexpected untranslated unit type for benchmark chart #{unit}"
      puts "Unexpected untranslated unit type for benchmark chart #{unit}"
      unit.to_s.humanize.gsub(' 0dp', '')
    end

    def remove_first_column(row)
      # return the data, the 1st entry is the column heading/series/label
      row[1..100]
    end

    def create_chart_data(config, table, chart_column_numbers, chart_columns_definitions)
      data, _y2_data = select_chart_data(config, table, chart_column_numbers, chart_columns_definitions, :y1)
      data
    end

    def create_y2_data(config, table, chart_column_numbers, chart_columns_definitions)
      _data, y2_data = select_chart_data(config, table, chart_column_numbers, chart_columns_definitions, :y2)
      y2_data
    end

    def select_chart_data(config, table, chart_column_numbers, chart_columns_definitions, axis)
      chart_data = {}
      y2_data = {}
      chart_column_numbers.each_with_index do |chart_column_number, index|
        next if index == 0 # skip entry as its the school name
        data = remove_first_column(table.map{ |row| row[chart_column_number] })
        series_name = chart_columns_definitions[index][:name]
        if axis == :y1 && self.class.y1_axis_column?(chart_columns_definitions[index])
          chart_data[series_name] = data
          percent_type = %i[percent relative_percent percent_0dp relative_percent_0dp].include?(chart_columns_definitions[1][:units])
          chart_data[series_name].map! { |val| val.nil? ? nil : val * 100.0 } if percent_type
        elsif axis == :y2 && self.class.y2_axis_column?(chart_columns_definitions[index])
          y2_data[series_name] = data
        end
      end
      [chart_data, y2_data]
    end

    def dated_attributes(suffix, school_data)
      school_data.transform_keys { |key| key.to_s + suffix }
    end

    def filter_row(row, filter)
      return true if filter.nil?
      row.instance_exec(&filter)
    end

    def calculate_row(row, report, chart_columns_only, school_id_debug)
      report[:columns].map do |column_specification|
        next if chart_columns_only && !self.class.chart_column?(column_specification)
        calculate_value(row, column_specification, school_id_debug)
      end
    end

    def rating_column?(column_specification)
      column_specification[:name] == 'rating'
    end

    def calculate_value(row, column_specification, school_id_debug)
      begin
        case column_specification[:data]
        when String then row.send(column_specification[:data])
        when Proc then row.instance_exec(&column_specification[:data]) # this calls the configs lambda as if it was inside the class of the database row, given the lambda access to all the row's variables
        else nil
        end
      rescue StandardError => e
        name = row.instance_exec(& ->{ school_name })
        logger.info format_rescue_message(e, school_id_debug, column_specification, name)
        return nil
      end
    end

    def format_rescue_message(e, school_id_debug, column_specification, name)
      line_number = column_specification.to_s.split(':')[4][0..3]
      "#{e.message}: school id #{school_id_debug} line #{line_number} #{name[0..10]}"
    end

    def all_school_ids(selected_dates)
      list_of_school_ids = {}
      selected_dates.each do |date|
        # puts "Got here: #{@benchmark_database.class.name}"
        # ap @benchmark_database
        school_ids = @benchmark_database[date].keys
        school_ids.each do |school_id|
          list_of_school_ids[school_id] = true
        end
      end
      list_of_school_ids.keys
    end
  end
end
