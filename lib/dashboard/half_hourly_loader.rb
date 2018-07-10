class HalfHourlyLoader
  include Logging

  def initialize(csv_file, date_column, data_start_column, header_rows, data)
    @data_start_column = data_start_column
    @date_column = date_column
    @header_rows = header_rows
    read_csv(csv_file, data)
  end

  def read_csv(csv_file, data)
    logger.debug "Reading #{data.type} data from '#{csv_file} date column = #{@date_column} data starts at col #{@data_start_column} skipping #{@header_rows} header rows"
    datareadings = Roo::CSV.new(csv_file)
    line_count = 0
    skip_rows = @header_rows
    datareadings.each do |reading|
      line_count += 1
      if skip_rows.zero?
        begin
          date = Date.parse(reading[@date_column])
          rowdata = reading[@data_start_column, @data_start_column + 47]
          rowdata = rowdata.map(&:to_f)
          data.add(date, rowdata)
        rescue StandardError => e
          logger.debug e.message
          logger.debug e.backtrace.join("\n")
          logger.debug "Unable to read data on line #{line_count} of file #{csv_file} date value #{reading[@date_column]}"
        end
      else
        skip_rows -= 1
      end
    end
    logger.debug "Read hash #{data.length} rows"
  end
end
