
class FloorAreaPupilNumbersBase
  def initialize(school_attributes, floor_area_key, pupil_key)
    return if school_attributes.nil?
    @floor_area_key = floor_area_key
    @pupil_key = pupil_key
    @area_pupils_history = process_meter_attributes(school_attributes) unless school_attributes.nil?
  end

  def floor_area(start_date = nil, end_date = nil)
    @area_pupils_history.nil? ? @floor_area : calculate_weighted_floor_area(start_date, end_date)
  end

  def number_of_pupils(start_date = nil, end_date = nil)
    @area_pupils_history.nil? ? @number_of_pupils : calculate_weighted_number_of_pupils(start_date, end_date)
  end

  private

  def process_meter_attributes(attributes)
    return nil if attributes.nil?

    attributes.map do |period|
      {
        start_date:         period.fetch(:start_date, Date.new(2000, 1, 1)),
        end_date:           period.fetch(:end_date,   Date.new(2050, 1, 1)),
        @floor_area_key =>  period[@floor_area_key],
        @pupil_key      =>  period[@pupil_key],
      }
    end.sort_by{ |period| period[:start_date] }
  end

  def calculate_weighted_floor_area(start_date, end_date)
    calculate_days_weighted_value(@floor_area_key, start_date, end_date)
  end

  def calculate_weighted_number_of_pupils(start_date, end_date)
    calculate_days_weighted_value(@pupil_key, start_date, end_date)
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

class FloorAreaPupilNumbers < FloorAreaPupilNumbersBase
  def initialize(floor_area, number_of_pupils, school_attributes)
    @floor_area = floor_area
    @number_of_pupils = number_of_pupils
    return nil if school_attributes.nil? || school_attributes[:floor_area_pupil_numbers].nil?
    super(school_attributes[:floor_area_pupil_numbers], :floor_area, :number_of_pupils)
  end

  def floor_area(start_date = nil, end_date = nil)
    @area_pupils_history.nil? ? @floor_area : calculate_weighted_floor_area(start_date, end_date)
  end

  def number_of_pupils(start_date = nil, end_date = nil)
    @area_pupils_history.nil? ? @number_of_pupils : calculate_weighted_number_of_pupils(start_date, end_date)
  end
end

class PartialMeterCoverage < FloorAreaPupilNumbersBase
  def initialize(partial_meter_attributes)
    super(partial_meter_attributes, :percent_floor_area, :percent_pupil_numbers)
  end

  def self.total_partial_floor_area(partial_meter_coverage, start_date = nil, end_date = nil)
    partial_floor_areas = to_array(partial_meter_coverage).map do |meter_partial_coverage|
      meter_partial_coverage.partial_floor_area(start_date, end_date)
    end
    partial_floor_areas.all?(&:nil?) ? 1.0 : partial_floor_areas.compact.sum
  end

  def self.total_partial_number_of_pupils(partial_meter_coverage, start_date = nil, end_date = nil)
    partial_number_of_pupils = to_array(partial_meter_coverage).map do |meter_partial_coverage|
      meter_partial_coverage.partial_number_of_pupils(start_date, end_date)
    end
    partial_number_of_pupils.all?(&:nil?) ? 1.0 : partial_number_of_pupils.compact.sum
  end

  def self.to_array(a)
    a.is_a?(Array) ? a : [a]
  end

  def partial_floor_area(start_date = nil, end_date = nil)
    @area_pupils_history.nil? ? nil : calculate_weighted_floor_area(start_date, end_date)
  end

  def partial_number_of_pupils(start_date = nil, end_date = nil)
    @area_pupils_history.nil? ? nil : calculate_weighted_number_of_pupils(start_date, end_date)
  end
end