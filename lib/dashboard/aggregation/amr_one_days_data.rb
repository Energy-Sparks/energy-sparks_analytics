# originally amr_data was inherited from half_hourly_data which was a hash to 48 x halfhourly readings
# to better represent whether the data has been artificially created as a result of bad or missing
# data OneDayAMRReading replaces the 48 x halfhourly readings
# 'type' is the higher level meta data (AMR_TYPES) describing the substitution if any
# additionally shadow data is held in some circumstances, so in the example of imperial to metric
# scaled gas data, the modified version is held as the primary data source, plus the original
# so the primary database key is meter_id, date, type => datax48
# internally in OneDayAMRReading the working data is held in :data_x48, plus the shadow data
# i.e. the flattened database representation is made hierarchical for that day for performance reasons
class OneDayAMRReading
  include Comparable
  include Logging

  attr_reader :meter_id, :date, :type, :substitute_date, :upload_datetime
  attr_reader :one_day_kwh, :kwh_data_x48

  def initialize(meter_id, date, type, substitute_date, upload_datetime, kwh_data_x48)
    check_type(type)
    @meter_id = meter_id.to_s
    @date = date
    @upload_datetime = upload_datetime
    @type = type
    @substitute_date = substitute_date
    @kwh_data_x48 = kwh_data_x48
    valid = validate_data
    if valid != 48
      throw EnergySparksBadAMRDataTypeException.new("Error: expecting all 48 half hour kWh values to be float or integer (#{valid})")
    end
    @one_day_kwh = kwh_data_x48.inject(:+)
  end

  def kwh_halfhour(half_hour_index)
    @kwh_data_x48[half_hour_index]
  end

  def set_kwh_halfhour(half_hour_index, kwh)
    @kwh_data_x48[half_hour_index] = kwh
    @one_day_kwh = kwh_data_x48.inject(:+)
  end

  def set_days_kwh_x48(days_kwh_data_x48)
    @kwh_data_x48 = days_kwh_data_x48
  end

  def set_type(type)
    @type = type
  end

  def check_type(type)
    if type.nil?
      throw EnergySparksBadAMRDataTypeException.new('Unexpected nil AMR bad data type')
    elsif !AMR_TYPES.key?(type)
      throw EnergySparksBadAMRDataTypeException.new("Unexpected AMR bad data type #{type}")
    end
  end

  def to_s
    date = @date.strftime('%d-%m-%Y')
    upload_datetime = @date.strftime('%d-%m-%Y %H:%M')
    sub_date = @substitute_date.nil? ? '' : @substitute_date.strftime('%d-%m-%Y')
    total = sprintf('%4.1f', @one_day_kwh)
    [date, @type, total, upload_datetime, sub_date, @kwh_data_x48].flatten.join(',')
  end

  def validate_data
    return 0 if !@kwh_data_x48.is_a?(Array)
    total = 0
    data_count = 0
    (0..47).each do |i|
      if kwh_halfhour(i).is_a?(Float) || kwh_halfhour(i).is_a?(Integer)
        data_count += 1
      end
    end
    if data_count != 48
      logger.info "Incomplete AMR data expecting 48 readings, got #{data_count} for date #{@date}"
      logger.info @kwh_data_x48
    end
    data_count
  end

  def <=>(other)
    other.class == self.class && 
    [meter_id, date, type, substitute_date] <=> [other.meter_id, other.date, other.type, other.substitute_date] &&
    one_day_kwh <=> other.one_day_kwh &&
    @kwh_data_x48 <=> other.kwh_data_x48
  end
end
