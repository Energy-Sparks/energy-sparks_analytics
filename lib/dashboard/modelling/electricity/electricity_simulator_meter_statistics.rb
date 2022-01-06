class ElectricitySimulator
  #=======================================================================================================================================================================
  # METER STATISTICS
  # used to help research work in analysing best fit
  # splits summary data into month buckets to help understand seasonality of fit
  class MeterStatistics
    attr_reader :results
    def initialize(meter, start_date, end_date, holidays)
      @meter = meter
      @start_date = start_date
      @end_date = end_date
      @holidays = holidays
      @results = {}
    end

    def calculate
      results[:annual_kwh] = @meter.amr_data.total_in_period(@start_date, @end_date)
      results[:baseload_kw] = @meter.amr_data.average_baseload_kw_date_range(@start_date, @end_date, sheffield_solar_pv: @meter.sheffield_solar_pv?)
      results[:night_baseload_kw] = @meter.amr_data.average_overnight_baseload_kw_date_range(@start_date, @end_date)
      results[:occupied_peak_kw] = calculate_peak_kw(true)
      results[:unoccupied_peak_kw] = calculate_peak_kw(false)
      results[:bymonth] = calculate_by_month
    end

    def print_statistics(stats)
      logger.info print_one_statistics_set(stats)
      stats[:bymonth].each do |month_name, month_stats|
        logger.info "  #{month_name} #{print_one_statistics_set(month_stats)}"
      end
    end

    def print_one_statistics_set(set)
      sprintf('Annual: %6.0fkWh BaseStat: %6.1fkW BaseNight: %6.1fkW Peak(occ): %6.1fkW Peak(unocc): %6.1fkW',
        set[:annual_kwh], set[:baseload_kw], set[:night_baseload_kw], set[:occupied_peak_kw], set[:unoccupied_peak_kw])
    end

    private

    def calculate_by_month
      stats_by_month = {}
      month_list = %w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
      month_list.each do |month_name|
        stats_by_month[month_name] = {
          annual_kwh: 0.0,
          baseload_kw: 0.0,
          night_baseload_kw: 0.0,
          day_count: 0.0,
          occupied_peak_kw: 0.0,
          occupied_count: 0,
          unoccupied_peak_kw: 0.0,
          unoccupied_count: 0
        }
      end
      (@start_date..@end_date).each do |date|
        month_name = date.strftime('%b')
        stats_by_month[month_name][:annual_kwh] += @meter.amr_data.one_day_kwh(date)
        stats_by_month[month_name][:baseload_kw] += @meter.amr_data.baseload_kw(date, @meter.sheffield_simulated_solar_pv_panels?)
        stats_by_month[month_name][:night_baseload_kw] += @meter.amr_data.overnight_baseload_kw(date)
        stats_by_month[month_name][:day_count] += 1
        if @holidays.occupied?(date)
          stats_by_month[month_name][:occupied_peak_kw] += @meter.amr_data.statistical_peak_kw(date)
          stats_by_month[month_name][:occupied_count] += 1
        else
          stats_by_month[month_name][:unoccupied_peak_kw] += @meter.amr_data.statistical_peak_kw(date)
          stats_by_month[month_name][:unoccupied_count] += 1
        end
      end
      stats_by_month.each_key do |month_name|
        stats_by_month[month_name][:baseload_kw] /= stats_by_month[month_name][:day_count] if stats_by_month[month_name][:day_count] > 0
        stats_by_month[month_name][:night_baseload_kw] /= stats_by_month[month_name][:day_count] if stats_by_month[month_name][:day_count] > 0
        stats_by_month[month_name][:occupied_peak_kw] /= stats_by_month[month_name][:occupied_count] if stats_by_month[month_name][:occupied_count] > 0
        stats_by_month[month_name][:unoccupied_peak_kw] /= stats_by_month[month_name][:unoccupied_count] if stats_by_month[month_name][:unoccupied_count] > 0
      end
      stats_by_month
    end
    def calculate_peak_kw(occupied)
      total = 0.0
      count = 0
      (@start_date..@end_date).each do |date|
        if occupied == @holidays.occupied?(date)
          total += @meter.amr_data.statistical_peak_kw(date)
          count += 1
        end
      end
      total / count
    end
  end

  def meter_statistics(meter)
    stats = MeterStatistics.new(meter, @period.start_date, @period.end_date, @holidays)
    stats.calculate
    res = stats.results
    # stats.print_statistics(res)
    res
  end

  def actual_data_statistics
    meter_statistics(@existing_electricity_meter)
  end

  def simulator_data_statistics
    meter_statistics(@school.electricity_simulation_meter)
  end
end