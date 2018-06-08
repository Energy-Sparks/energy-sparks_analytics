require_relative '../half_hourly_data'

class AMRData < HalfHourlyData
  def initialize(type)
    super(type)
  end

  def kwh(date, halfhour_index)
    data(date, halfhour_index)
  end

  def baseload_kw(date)
    total = 0.0
    (41..47).each do |halfhour_index|
      total += data(date, halfhour_index)
    end
    total * 2.0 / 7.0
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
