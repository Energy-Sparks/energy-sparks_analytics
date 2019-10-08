require 'write_xlsx'

# takes a hash of aggregated AMR data and adds it as a chart to an excel spreadsheet for testing purposes
class ExcelCharts
  include Logging
  include Writexlsx::Utility

  def initialize(filename)
    @filename = filename
    @workbook = WriteXLSX.new(@filename)
    @bold = @workbook.add_format(bold: 1)
    @colour_cache = {} # Excel only has 56 colours, so we need to set custom colours and cache them
  end

  def custom_colour(hex_colour)
    if @colour_cache.key?(hex_colour)
      @colour_cache[hex_colour]
    else
      colour_num = 63 - @colour_cache.length
      new_colour_name = 'custom-colour-' + colour_num.to_s
      r, g, b = hex_colour_to_rgb(hex_colour)
      @workbook.set_custom_color(colour_num, r, g, b)
      logger.debug "Setting #{new_colour_name} to #{r} #{g} #{b}"
      @colour_cache[hex_colour] = new_colour_name
      new_colour_name
    end
  end

  def hex_colour_to_rgb(hex)
    r = hex[1..2].hex
    g = hex[3..4].to_i(16)
    b = hex[5..6].to_i(16)
    [r, g, b]
  end

  def add_data(worksheet_name, half_hourly_data)
    worksheet = @workbook.add_worksheet(worksheet_name)

    rows = []

    # amr_data is of the form {has_date} = 48 x kWh readings: unpack into a grid - using the date as the first column
    (half_hourly_data.get_first_date..half_hourly_data.get_last_date).each do |date|
      row = []
      row.push(date)
      (0..47).each do |half_hour_index|
        row.push(half_hourly_data.get_data(date, half_hour_index))
      end
      rows.push(row)
    end

    worksheet.write_col('1', rows)
  end

  def find_sheet(worksheet_name)
    @workbook.sheets.each do |worksheet|
      if worksheet.name == worksheet_name
        return worksheet
      end
    end
  end

  # add hash of hash to array data to spreadsheet for debudding purpoes
  def add_rawdata(worksheet_name, raw_data)
    worksheet = find_sheet(worksheet_name)
    start_row = 1
    start_col = 20

    raw_data.each do |key, value|
      row = start_row
      worksheet.write(row, start_col, key)
      value.each do |key2, value2|
        worksheet.write(start_row + 1, start_col, key2)
        row = start_row
        value2.each do |data|
          row += 1
          worksheet.write(row, start_col, data)
        end
        start_col += 1
      end
    end
  end

  def add_data_and_chart_to_excel_worksheet(worksheet, column_number, xaxis_data, data, chart, second_y_axis, chart_type, data_labels = nil, trendline = nil)
    start_column_number = column_number
    first_data_column = start_column_number
    max_data_rows = 0
    # column_headings = data.keys
    # excel_data = []

    # if data labels provided e.g. dates on scatter plot write to column 1 before data
    # write_xlsx doesn't support data labels for charts, suspect because the Excel ECMA xlsx
    # definition is complex to implement? So the data is added for debugging purposes
    # and the labels need to be manually assigned in Excel afterwards
    unless data_labels.nil?
      worksheet.write_col(1, start_column_number - 1, data_labels)
    end

    unless xaxis_data.nil?
      worksheet.write_col(1, start_column_number, xaxis_data)
      column_number += 1
      first_data_column += 1
    end

    column_number_to_name_map = {}

    data.each do |column_name, column_data|
      unless column_data.is_a?(Symbol)
        worksheet.write(0, column_number, column_name)
        column_number_to_name_map[column_number] = column_name
        worksheet.write_col(1, column_number, column_data)
        max_data_rows = column_data.length
        column_number += 1
      end
    end

    category_range = cell_reference(worksheet.name, start_column_number, 2, start_column_number, max_data_rows + 1)
    last_data_column = first_data_column + data.length - 1

    (first_data_column..last_data_column).each do |col_num|
      col_name = column_number_to_name_map[col_num]
      colour_hex = @colours.series_colour(col_name) unless col_name.nil?
      name_range = cell_reference(worksheet.name, col_num, 1, col_num, 1)
      value_range = cell_reference(worksheet.name, col_num, 2, col_num, max_data_rows + 1)

      args = { name: name_range, values: value_range }

      if second_y_axis
        args[:y2_axis] = 1
      else
        args[:categories] = category_range
      end

      data.each do |column_name, trendline_column|
        if trendline_column.is_a?(Symbol)
          if trendline_column == col_name
            args.merge!(trendline: { type: 'linear', name: column_name.to_s })
          end
        end
      end
      args.merge!(fill: { color: colour_hex }, line: { color: colour_hex }) unless [:pie, :scatter].include?(chart_type)

      chart.add_series(args) unless col_name.nil?
    end

    column_number
  end

  def new_chart(type, subtype)
    if !subtype.nil?
      @workbook.add_chart(type: type.to_s, subtype: subtype.to_s, embedded: 1)
    else
      @workbook.add_chart(type: type.to_s, embedded: 1)
    end
  end

  def add_charts(worksheet_name, charts)
    data_col_offset = 10
    chart_row_offset = 1
    logger.debug "Adding a new worksheet: #{worksheet_name}"
    worksheet = @workbook.add_worksheet(worksheet_name)
    charts.each do |chart|
      add_chart(worksheet, chart, data_col_offset, chart_row_offset)
      data_col_offset += 40
      chart_row_offset += 22
    end
  end

  def add_graph_and_data(worksheet_name, graph_definition)
    logger.debug "creating new worksheet #{worksheet_name}"
    worksheet = @workbook.add_worksheet(worksheet_name)
    add_chart(worksheet, graph_definition, 0, 0)
  end

  # the write_xlsx gem seems to produce corrupt Excel
  # if text contains a £ symbol
  def clean_text(text)
    text.tr('£', '$')
  end

  def add_chart(worksheet, graph_definition, data_col_offset, chart_row_offset)
    chart2 = nil

    @colours = ChartColour.new(graph_definition)

    ap(graph_definition, limit: 500, color: { float: :red }) if ENV['AWESOMEPRINT'] == 'on'

    logger.error "Error: null graph definition" if graph_definition.nil?

    main_axisx = graph_definition[:x_axis].clone
    main_axisdata = graph_definition[:x_data].clone

    chart1 = new_chart(graph_definition[:chart1_type], graph_definition[:chart1_subtype])

    subtitle = graph_definition.key?(:subtitle) ? "Subtitle: #{graph_definition[:subtitle]}" : ''
    chart1.set_title(name: clean_text(graph_definition[:title] + subtitle))
    chart1.set_y_axis(name: clean_text(graph_definition[:y_axis_label]))

    if graph_definition[:chart1_type] == :pie # special case for pie charts, need to swap axis
      main_axisx = graph_definition[:x_data].keys
      main_axisdata = {}
      main_axisdata['No Dates'] = Array.new(main_axisx.length, 0.0)
      (0..main_axisx.length - 1).each do |i|
        main_axisdata['No Dates'][i] = graph_definition[:x_data][main_axisx[i]][0]
      end
    end

    column_number = add_data_and_chart_to_excel_worksheet(
      worksheet,
      data_col_offset,
      main_axisx,
      main_axisdata,
      chart1,
      false,
      graph_definition[:chart1_type],
      graph_definition[:data_labels] || nil,
      graph_definition[:trendlines] || nil
    )

    # second set of data but on secondary y axis, but sharing the same xaxis
    if graph_definition.key?(:y2_chart_type) && !graph_definition[:y2_chart_type].nil?
      chart2 = new_chart(graph_definition[:y2_chart_type], graph_definition[:y2_chart_subtype])
      _column_number = add_data_and_chart_to_excel_worksheet(
        worksheet,
        column_number,
        nil,
        graph_definition[:y2_data],
        chart2,
        true,
        graph_definition[:chart1_type]
      )
    end

    chart1.combine(chart2) unless chart2.nil?

    # insert chart into Excel offset each time so multiple charts don;t overlap
    chart_cell_start_ref = single_cell_reference(1, chart_row_offset, false, false)
    worksheet.insert_chart(chart_cell_start_ref, chart1, 12, 5, 1.5, 1.5)
  end

  def cell_reference(worksheet_name, col_num_start, row_number_start, col_num_end, row_number_end)
    # logger.debug Writexlsx::Utility::xl_range(row_number_start, row_number_end, col_num_start, col_num_end, true, true, true, true)
    if col_num_start == col_num_end && row_number_start == row_number_end
      '=' + encapsulate_worksheet_name(worksheet_name) + '!' + single_cell_reference(col_num_start, row_number_start, true, true)
    else
      '=' + encapsulate_worksheet_name(worksheet_name) + '!' + cell_reference_noworksheet(col_num_start, row_number_start, col_num_end, row_number_end)
    end
  end

  def encapsulate_worksheet_name(worksheet_name)
    # rubocop:disable all, Performance/RedundantMatch
    if worksheet_name.match(/\s/)
      "'" << worksheet_name << "'"
    else
      worksheet_name
    end
    # rubocop:enable all, Performance/RedundantMatch
  end

  def cell_reference_noworksheet(col_num_start, row_number_start, col_num_end, row_number_end)
    "" << single_cell_reference(col_num_start, row_number_start, true, true) << ":" << single_cell_reference(col_num_end, row_number_end, true, true)
  end

  def single_cell_reference(col_num, row_num, abs_col, abs_row)
    # Writexlsx::Utility mixin call seems to be 1 off on row number
    # compared with the original function within this class?
    xl_rowcol_to_cell(row_num - 1, col_num, abs_row,  abs_col)
  end

  def close
    @workbook.close
  end
end
