class RunTargetingAndTracking < RunAdultDashboard
  def self.default_control_settings
    {
      control: {
        root:    :adult_analysis_page,
        display_average_calculation_rate: true,
        summarise_differences: true,
        report_failed_charts:   :summary,
        user: { user_role: :analytics, staff_role: nil },

        pages: %i[electric_target gas_target],
        compare_results: [
          { comparison_directory: ENV['ANALYTICSTESTRESULTDIR'] + '\TargetingAndTracking\Base' },
          { output_directory:     ENV['ANALYTICSTESTRESULTDIR'] + '\TargetingAndTracking\New' },
          :summary,
          :report_differences,
          :report_differing_charts,
        ]
      }
    }
  end

  def run_flat_dashboard(control)
    differing_pagess = {}

    scenarios = control[:scenarios]

    annual_kwh_estimates = calculate_annual_kwh

    ap annual_kwh_estimates

    scenarios.each do |scenario|
      @school.reset_target_school_for_testing
      set_filenames(scenario)
      set_page_name(scenario)
      deleted_amr_data = configure_scenario(scenario, annual_kwh_estimates)
      differing_pages = super(control)
      differing_pages.transform_keys!{ |k| :"#{k} #{@filename_type}" }
      differing_pagess.merge!(differing_pages)
      reinstate_deleted_amr_data(deleted_amr_data)
    end

    differing_pagess
  end

  private

  def configure_scenario(scenario, annual_kwh_estimates)
    deleted_amr_data = {}

    scenario[:fuel_types].each do |fuel_type|
      meter = @school.aggregate_meter(fuel_type)

      meter.reset_targeting_and_tracking_for_testing

      next if meter.nil?
      
      set_target(meter, scenario[:target_start_date], scenario[:target])

      deleted_amr_data[fuel_type] = truncate_amr_data(meter, scenario[:truncate_amr_data])
 
      set_kwh_estimate(meter, annual_kwh_estimates[fuel_type], scenario[:target_start_date])
    end

    deleted_amr_data
  end

  def reinstate_deleted_amr_data(deleted_amr_data)
    deleted_amr_data.each do |fuel_type, days_amr_data|
      meter = @school.aggregate_meter(fuel_type)
      days_amr_data.each do |one_day_amr_data|
        meter.amr_data.add(one_day_amr_data.date, one_day_amr_data)
      end
    end
  end

  def start_date_target(meter, target_start_date)
    target_start_date.is_a?(Date) ? target_start_date : (meter.amr_data.end_date + target_start_date)
  end

  def set_target(meter, target_start_date, target)
    start_date = start_date_target(meter, target_start_date)

    pseudo_meter_key = Dashboard::Meter.aggregate_pseudo_meter_attribute_key(meter.fuel_type)
    
    # historic: delete attributes manually configured via generic meter attribute editor
    meter.meter_attributes.delete(:targeting_and_tracking)

    @school.delete_pseudo_meter_attribute(pseudo_meter_key, :targeting_and_tracking)
  
    new_attributes = {
                        targeting_and_tracking: [
                                                  {
                                                    start_date: start_date,
                                                    target:     target
                                                  }
                                                ]
                      }

    pseudo_attributes = { pseudo_meter_key => new_attributes }
    @school.merge_additional_pseudo_meter_attributes(pseudo_attributes)
  end

  def set_kwh_estimate(meter, annual_kwh_estimate, target_start_date)
    start_date = start_date_target(meter, target_start_date)

    # don't set attribute if already enough data
    return if (start_date - meter.amr_data.start_date) > 365

    # historic: delete attributes manually configured via generic meter attribute editor
    meter.meter_attributes.delete(:estimated_period_consumption)

    pseudo_meter_key = Dashboard::Meter.aggregate_pseudo_meter_attribute_key(meter.fuel_type)

    @school.delete_pseudo_meter_attribute(pseudo_meter_key, :estimated_period_consumption)

    kwh = annual_kwh_estimate[:kwh] / annual_kwh_estimate[:percent]
  
    new_attributes = {
                        estimated_period_consumption: [
                                                        {
                                                          start_date: start_date - 365,
                                                          end_date:   start_date - 1,
                                                          kwh:        kwh
                                                        }
                                                      ]
                      }

    pseudo_attributes = { pseudo_meter_key => new_attributes }
    @school.merge_additional_pseudo_meter_attributes(pseudo_attributes)
    meter.calculate_annual_kwh_estimate
  end

  def truncate_amr_data(meter, days_left)
    deleted_amr_data = []
    if days_left < meter.amr_data.days
      last_truncate_date = meter.amr_data.end_date - days_left + 1
      deleted_amr_data = meter.amr_data.delete_date_range(meter.amr_data.start_date, last_truncate_date)
      meter.amr_data.set_start_date(last_truncate_date + 1)
    end
    deleted_amr_data
  end

  def calculate_annual_kwh
    estimates = {}

    %i[electricity gas storage_heater].each do |fuel_type|
      meter = @school.aggregate_meter(fuel_type)
      next if meter.nil?

      ed = meter.amr_data.end_date
      sd = [meter.amr_data.start_date, ed - 364].max

      estimates[fuel_type] = {
        kwh:      meter.amr_data.kwh_date_range(sd, ed),
        percent:  (ed - sd + 1) / 365.0
      }
    end

    estimates
  end

  def set_filenames(scenario)
    @filename_type = "TnT #{type(scenario)}"
  end

  def set_page_name(scenario)
    @page_type = "TnT #{type(scenario)}"
  end

  def type(scenario)
    "sd=#{scenario[:target_start_date]},ad=#{scenario[:truncate_amr_data]},t=#{scenario[:target]}"
  end

  def excel_variation
    @filename_type.nil? ? 'TnT' : @filename_type
  end

  def write_html
    super(filename_suffix: @filename_type)
  end

  def comparison_differences(control, school_name, page, content)
    comparison = CompareContentResults.new(control, school_name)

    page_name = :"#{page}#{@page_type}"
    comparison.save_and_compare_content(page_name, content, true)
  end
end
