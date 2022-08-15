class FloorAreaPupilNumbersTableBase
  def initialize(floor_area_pupil_numbers)
    @floor_area_pupil_numbers = floor_area_pupil_numbers
  end

  def table_html
    format_table
  end

  private

  def format_table(date_format: '%b %Y')
    header = ['Date range', type.to_s.humanize]

    formatted_data = data.map do |row|
      [
        date_range_html(row[:start_date], row[:end_date], date_format: date_format),
        row[type]
      ]
    end

    tbl = HtmlTableFormatting.new(header, formatted_data)

    tbl.html
  end

  private

  def date_range_html(start_date, end_date, date_format:)
    if start_date.nil?
      "to #{end_date.strftime(date_format)}"
    elsif end_date.nil?
      "from #{start_date.strftime(date_format)}"
    else
      "#{start_date.strftime(date_format)} to #{end_date.strftime(date_format)}"
    end
  end

  def data
    @floor_area_pupil_numbers.area_pupils_history.map do |period|
      {
        :start_date => period[:start_date] == FloorAreaPupilNumbersBase::DEFAULT_START_DATE ? nil : period[:start_date],
        :end_date   => period[:end_date]   == FloorAreaPupilNumbersBase::DEFAULT_END_DATE ? nil : period[:end_date],
        type        => period[type]
      }
    end.uniq
  end
end

class FloorAreaTable < FloorAreaPupilNumbersTableBase
  def type
    :floor_area
  end
end

class PupilNumbersTable < FloorAreaPupilNumbersTableBase
  def type
    :number_of_pupils
  end
end
