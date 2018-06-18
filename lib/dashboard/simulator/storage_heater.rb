# StorageHeaters are a group of StorageHeaterDefinition
# to allow for a mix of heaters in any given school
# with different time controls, or a change in their
# setup over time
class StorageHeaters
  def initialize
    @storage_heaters = []
  end

  def add_storage_heaters(storage_heater_group)
    @storage_heaters.push(storage_heater_group)
  end

  def capacity_at_time_of_day(date, halfhour_index)
    capacity = 0.0
    @storage_heaters.each do |storage_heater|
      _d, start_time_halfhour_index = DateTimeHelper.time_to_date_and_half_hour_index(storage_heater.start_time)
      _d, end_time_halfhour_index = DateTimeHelper.time_to_date_and_half_hour_index(storage_heater.end_time)
      next if storage_heater.timer == :day7 && date.saturday?
      next if storage_heater.timer == :day7 && date.sunday? && start_time_halfhour_index < end_time_halfhour_index
      if start_time_halfhour_index < end_time_halfhour_index &&
        halfhour_index >= start_time_halfhour_index &&
        halfhour_index <= end_time_halfhour_index
        capacity += storage_heater.kwp
      elsif start_time_halfhour_index > end_time_halfhour_index
        (halfhour_index >= start_time_halfhour_index || # storage heater set to start before midnight
        halfhour_index <= end_time_halfhour_index)
        capacity += storage_heater.kwp
      end
    end
    capacity
  end

  def max_capacity_kw_on_day(date)
    total_capacity = 0.0
    storage_heaters.each do |storage_heater|
      if storage_heater.start_date >= date && storage_heater.end_date <= date
        total_capacity += storage_heater.kwp
      end
    end
    total_capacity
  end

  BASELOAD_FACTOR = 1.5
  # splits 1 electricity AMR data set into 2, 1 with just the storage heater data
  # 1 without the storage heater data
  def disaggregate_amr_data(amr_data)
    storage_heater_amr_data = AMRData.new(:stroage_heater)
    electricity_only_amr_data = AMRData.new(:electricity)
    amr_data.each do |date, days_half_hourly_kwh|
      baseload_sample_date = date > amr_data.start_date ? date - 1 : date
      baseload_kwh = amr_data.statistical_baseload_kw(date) / 2.0
      storage_heater_kwh = Array.new(48, 0.0)
      storage_heater_amr_data.add(date, storage_heater_kwh)
      electric_only_kwh = Array.new(48, 0.0)
      electricity_only_amr_data.add(date, electric_only_kwh)
      (0..47).each do |halfhour_index|
        storage_heater_capacity = capacity_at_time_of_day(date, halfhour_index)
        kwh = amr_data.kwh(date,halfhour_index)
        if storage_heater_capacity > 0 && kwh > baseload_kwh * BASELOAD_FACTOR
          storage_heater_kwh[halfhour_index] = kwh - baseload_kwh
          electric_only_kwh[halfhour_index] = baseload_kwh
        else
          electric_only_kwh[halfhour_index] = kwh
        end
      end
    end
    # diagnostics
    total_kwh = amr_data.kwh_date_range(amr_data.start_date, amr_data.end_date)
    sh_kwh = storage_heater_amr_data.kwh_date_range(amr_data.start_date, amr_data.end_date)
    eo_kwh = electricity_only_amr_data.kwh_date_range(amr_data.start_date, amr_data.end_date)
    puts "Splitting meter for storage heater: original #{total_kwh} kwh => storage heater #{sh_kwh} + remainder = #{eo_kwh}"
    [electricity_only_amr_data, storage_heater_amr_data]
  end

  def self.create_storage_heaters_from_yaml_storage_heater_definition(yaml_storage_meters)
    storage_heaters = StorageHeaters.new
    yaml_storage_meters.each do |yaml_storage_heater|
      storage_heater = StorageHeaterDefinition.new(
        yaml_storage_heater[:kwp],
        yaml_storage_heater[:start_date],
        yaml_storage_heater[:end_date],
        yaml_timer(yaml_storage_heater[:timer]),
        yaml_time_of_day(yaml_storage_heater[:start_time]),
        yaml_time_of_day(yaml_storage_heater[:end_time])
      )
      storage_heaters.add_storage_heaters(storage_heater)
    end
    storage_heaters
  end

private

  def self.yaml_timer(timer_str)
    if timer_str == '24h'
      :h24
    elsif timer_str == '7day'
      :day7
    else
      raise ArgumentError.new("Unknown storage heater controller type #{timer_str}")
    end
  end

  def self.yaml_time_of_day(time_of_day_str)
    hour = time_of_day_str[0..1].to_i
    minutes = time_of_day_str[3..4].to_i
    Time.new(0,1,1,hour,minutes,0)
  end
end

# definition of a group of storage heaters, a place holder for data
# which is then interpreted across a number of groups by the parent
# StorageHeaters class
class StorageHeaterDefinition
  attr_reader :kwp, :start_date, :end_date, :timer, :start_time, :end_time
  def initialize(kwp, start_date, end_date, timer, start_time, end_time)
    @kwp = kwp
    @start_date = start_date
    @end_date = end_date
    @timer = timer
    @start_time = start_time
    @end_time = end_time
  end
end