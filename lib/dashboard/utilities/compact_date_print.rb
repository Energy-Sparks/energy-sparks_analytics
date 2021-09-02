# for debugging purposes log array of dates compactly:
# if range: 'date 1' to 'date 2'
# if single dates, in columns 'date 1' 'date 2'.......'date max_columns'
class CompactDatePrint
  include Logging

  def initialize(dates, max_columns = 6, date_format = '%a %d%b%y')
    @dates = dates
    @max_columns = max_columns
    @date_format = date_format
  end

  def log
    debug_output_dates(@dates)
  end

  private

  # format missing dates compactly: ranges d1 to d2, or single dates d1, d2, d3.....dN
  def debug_output_dates(dates)
    date_ranges = group_consecutive_dates(dates)

    single_dates = []
    date_ranges.each do |start_date, count|
      if single_dates.length == @max_columns # max N dates per line
        output_single_dates(single_dates)
        single_dates = []
      end
      if count > 1
        unless single_dates.empty?
          logger.debug output_single_dates(single_dates)
          single_dates = []
        end
        d1 = start_date.strftime(@date_format)
        d2 = (start_date + count - 1).strftime(@date_format)
        logger.debug "     #{d1} to #{d2} * #{count}"
      else
        single_dates.push(start_date)
      end
    end
    logger.debug output_single_dates(single_dates) unless single_dates.empty?
  end

  def output_single_dates(dates)
    line_output = '    '
    dates.each do |date|
      line_output += ' ' + date.strftime(@date_format)
    end
    line_output
  end

  # group dates into consecutive date ranges, returns {date} = count of consecutive dates
  def group_consecutive_dates(dates)
    start_date_range = nil
    date_count = {}
    dates.each do |date|
      if start_date_range.nil? # first date
        start_date_range = date
        date_count[start_date_range] = 1
      elsif start_date_range + date_count[start_date_range] == date
        date_count[start_date_range] += 1 # extend range by one day
      else # end of range, or single date
        start_date_range = date
        date_count[start_date_range] = 1
      end
    end
    date_count
  end
end 
