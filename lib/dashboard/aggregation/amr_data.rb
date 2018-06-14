require_relative '../half_hourly_data'

class AMRData < HalfHourlyData
  def initialize(type)
    super(type)
  end

  def kwh(date, halfhour_index)
    data(date, halfhour_index)
  end

  def baseload_kw(date)
    baseload_kw_between_half_hour_indices(date, 41, 47)
  end

  def baseload_kw_between_half_hour_indices(date, hhi1, hhi2)
    total_kwh = 0.0
    count = 0
    if hhi2 > hhi1 # same day
      (hhi1..hhi2).each do |halfhour_index|
        total_kwh += data(date, halfhour_index)
        count += 1
      end
    else
      (hhi1..48).each do |halfhour_index| # before midnight
        total_kwh += data(date, halfhour_index)
        count += 1
      end
      (0..hhi2).each do |halfhour_index| # after midnight
        total_kwh += data(date, halfhour_index)
        count += 1
      end
    end
    total_kwh * 2.0 / count
  end

  # alternative heuristic for baseload calculation (for storage heaters)
  # find the average of the bottom 8 samples (4 hours) in a day
  def statistical_baseload_kw(date)
    days_data = self[date] # 48 x 1/2 hour kWh
    sorted_kwh = days_data.clone.sort
    lowest_sorted_kwh = sorted_kwh[0..7]
    average_kwh = lowest_sorted_kwh.inject{ |sum, el| sum + el }.to_f / lowest_sorted_kwh.size
    average_kwh * 2.0 # convert to kW
  end

  def average_baseload_kw_date_range(date1, date2)
    baseload_kwh_date_range(date1, date2) / (date2 - date1 + 1)
  end

  def baseload_kwh_date_range(date1, date2)
    total = 0.0
    (date1..date2).each do |date|
      total += baseload_kw(date)
    end
    total
  end

  def one_day_kwh(date)
    one_day_total(date)
  end

  def kwh_date_range(date1, date2)
    total_kwh = 0.0
    (date1..date2).each do |date|
      total_kwh += one_day_kwh(date)
    end
    total_kwh
  end

  def kwh_date_list(dates)
    total_kwh = 0.0
    dates.each do |date|
      total_kwh += one_day_kwh(date)
    end
    total_kwh
  end
end

class AMRLoader < HalfHourlyLoader
  def initialize(csv_file, amrdata)
    super(csv_file, 2, 3, 0, amrdata)
  end
end

class AMRLoadExcelRawData < HalfHourlyLoader
  def initialize(csv_file, amrdata)
    super(csv_file, 0, 1, 3, amrdata)
  end
end
