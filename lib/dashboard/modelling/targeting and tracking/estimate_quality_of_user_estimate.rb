class QualityOfUserTargetAndTrackingAnnualEstimate
  def initialize(meter, target_dates, data)
    @meter = meter
    @target_dates = target_dates
    @data = data
  end

  def calculate
    est = @meter.meter_collection.target_school.annual_kwh_estimate_kwh(@meter)

    benchmark_ratio = ratio_of_occupied_to_unoccupied_consumption(@meter, @meter.amr_data,  @target_dates.benchmark_start_date,           @target_dates.benchmark_end_date)
    synthetic_ratio = ratio_of_occupied_to_unoccupied_consumption(@meter, @data[:amr_data], @target_dates.synthetic_benchmark_start_date, @target_dates.benchmark_start_date - 1)
    analysis = analyse_stats(benchmark_ratio, synthetic_ratio)
    @data[:feedback][:quality_of_estimate] = {
      annual_kwh_estimate: est,
      benchmark_data_stats: benchmark_ratio,
      synthetic_data_stats: synthetic_ratio,
      analysis:             analysis
    }
  end

  private

  def ratio_of_occupied_to_unoccupied_consumption(meter, amr_data, start_date, end_date)
    lambda = -> (date) { amr_data.one_day_kwh(date) }
    stats = meter.meter_collection.holidays.daytype_analysis(start_date, end_date, lambda, calculations: %i[average count total])
    occupied_unoccupied_ratio = percent(stats[:schoolday][:average], stats[:unoccupied][:average])
    {
      statistics:                 stats,
      start_date:                 start_date,
      end_date:                   end_date,
      occupied_unoccupied_ratio:  occupied_unoccupied_ratio,
    }
  end

  def analyse_stats(benchmark, synthetic)
    puts synthetic[:statistics][:all][:count], benchmark[:statistics][:all][:count]
    {
      percent_synthetic_data:     percent_total(synthetic[:statistics][:all][:count], benchmark[:statistics][:all][:count]),
      occupied_unoccupied_ratios: percent(synthetic[:occupied_unoccupied_ratio], benchmark[:occupied_unoccupied_ratio])
    }
  end

  def percent_total(v1, v2)
    t = v1 + v2
    t == 0.0 ? 0.0 : v1.to_f / t
  end

  def percent(v1, v2)
    v2 == 0.0 ? 0.0 : v1 / v2
  end
end
