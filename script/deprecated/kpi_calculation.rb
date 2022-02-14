class KPICalculation
  attr_reader :calculation_results, :school_name
  def initialize(school)
    @school = school
    @school_name = @school.name
    @calculation_results = Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }
  end

  def run_kpi_calculations
    puts "=" * 80
    puts "KPI calculations for #{school_name}"
    calculate_hot_water_breakdown
    calculate_scalar_values
  end

  private def calculate_hot_water_breakdown
    breakdown = AnalyseHeatingAndHotWater::HeatingAndHotWaterBreakdown.new(@school)

    this_year = breakdown.breakdown

    unless this_year.nil?
      previous_year_end_date = this_year[:start_date] - 1

      degreeday_info = degreeday_adjustment(this_year[:start_date], this_year[:end_date])
      @calculation_results[school_name][:heat][ 0][:degree_days] = degreeday_info[:degreedays_this_year]
      @calculation_results[school_name][:heat][-1][:degree_days] = degreeday_info[:degreedays_last_year]

      previous_year = breakdown.breakdown(end_date: previous_year_end_date, change_in_degree_days_percent: degreeday_info[:degreeday_adjustment_percent])

      @calculation_results[school_name][:gas][ 0][:annual_kwh]               = this_year[:total_kwh]
      @calculation_results[school_name][:gas][ 0][:hw_percent]               = this_year[:hot_water_percent_of_total_kwh]
      @calculation_results[school_name][:gas][-1][:annual_kwh]               = this_year[:total_kwh]
      unless previous_year.nil?
        @calculation_results[school_name][:gas][-1][:annual_kwh_adjusted]      = previous_year[:total_adjusted_kwh]
        @calculation_results[school_name][:gas][-1][:degreeday_adjustment]     = previous_year[:degreeday_adjustment_percent]
        @calculation_results[school_name][:gas][-1][:total_adjustment_percent] = previous_year[:percent_change_due_to_adjustment]
      end
    end
  end

  private def degreeday_adjustment(this_year_start_date, this_year_end_date)
    degreedays_this_year = @school.temperatures.degree_days_in_date_range(this_year_start_date,  this_year_end_date)

    previous_year_end_date = this_year_start_date - 1
    previous_year_start_date = previous_year_end_date - 365
    degreedays_last_year = @school.temperatures.degree_days_in_date_range(previous_year_start_date,  previous_year_end_date)

    degreeday_adjustment_percent = (degreedays_this_year - degreedays_last_year) / degreedays_this_year
    {
      degreedays_this_year:         degreedays_this_year,
      degreedays_last_year:         degreedays_last_year,
      degreeday_adjustment_percent: degreeday_adjustment_percent
    }
  end

  private def calculate_scalar_values
    %i[electricity gas storage_heaters].each do |fuel_type|
      next if @school.aggregate_meter(fuel_type).nil?
      [0, -1].each do |year|
        [:kwh, :co2].each do |data_type|
          @calculation_results[school_name][fuel_type][year][data_type] = ScalarkWhCO2CostValues.new(@school).day_type_breakdown({year: year}, fuel_type, data_type)
        rescue EnergySparksNotEnoughDataException => _e
          puts "Less than 2 years of data for #{school_name}"
        end
      end
    end
  end

  def self.save_kpi_calculation_to_csv(config, calculation_results)
    File.open(config[:filename], 'w') do |f|
      calculation_results.each do |school_name, fuel_types|
        fuel_types.each do |fuel_type, years|
          years.each do |year, data_types|
            data_types.each do |data_type, value|
              data = [
                school_name,
                fuel_type,
                year,
                data_type
              ]
              if value.is_a?(Float)
                data.push(value)
                f.puts data.join(', ')
              else
                value.each do |school_day_type, val|
                  school_day_type_data = data + [school_day_type, val]
                  f.puts school_day_type_data.join(', ')
                end
              end
            end
          end
        end
      end
    end
  end
end