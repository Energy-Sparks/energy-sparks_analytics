
class FloorAreaPupilNumbers
  def initialize(meter_collection, floor_area, number_of_pupils, school_attributes)
    @meter_collecton = meter_collection
    @floor_area = floor_area
    @number_of_pupils = number_of_pupils
    @area_pupils_history = process_meter_attributes(school_attributes)
  end

  def floor_area(start_date = nil, end_date = nil)
    @area_pupils_history.nil? ? @floor_area : calculate_weighted_floor_area(start_date, end_date)
  end

  def number_of_pupils(start_date = nil, end_date = nil)
    @area_pupils_history.nil? ? @number_of_pupils : calculate_weighted_number_of_pupils(start_date, end_date)
  end

  private

  def process_meter_attributes(school_attributes)
    return nil if school_attributes.nil?
    return nil unless school_attributes.key?(:floor_area_pupil_numbers)

    school_attributes[:floor_area_pupil_numbers].map do |period|
      {
        start_date:       period.fetch(:start_date, Date.new(2000, 1, 1)),
        end_date:         period.fetch(:end_date,   Date.new(2050, 1, 1)),
        floor_area:       period[:floor_area],
        number_of_pupils: period[:number_of_pupils],
      }
    end.sort_by{ |period| period[:start_date] }
  end

  def calculate_weighted_floor_area(start_date, end_date)
    calculate_days_weighted_value(:floor_area, start_date, end_date)
  end

  def calculate_weighted_number_of_pupils(start_date, end_date)
    calculate_days_weighted_value(:number_of_pupils, start_date, end_date)
  end

  def calculate_days_weighted_value(field, start_date, end_date)
    start_date = end_date = Date.today if start_date.nil? || end_date.nil?
    
    start_index = date_index(@area_pupils_history, start_date)
    end_index   = date_index(@area_pupils_history, end_date)

    return @area_pupils_history[start_index][field] if start_index == end_index

    weighted_areas = (start_index..end_index).to_a.map do |period_index|
      sd = [@area_pupils_history[period_index][:start_date], start_date].max
      ed = [@area_pupils_history[period_index][:end_date],   end_date  ].min
      {
        days:  1 + (ed - sd).to_i,
        value: @area_pupils_history[period_index][field]
      }
    end
    # map then sum to avoid statsample bug
    weighted_areas.map{ |we| we[:days] * we[:value] }.sum /  weighted_areas.map{ |we| we[:days] }.sum
  end

  def date_index(arr, date)
    arr.bsearch_index {|p| date < p[:start_date] ? -1 : date > p[:end_date] ? 1 : 0 }
  end
end