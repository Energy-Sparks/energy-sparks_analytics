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
          { comparison_directory: 'C:\Users\phili\Documents\TestResultsDontBackup\TargetingAndTracking\Base' },
          { output_directory:     'C:\Users\phili\Documents\TestResultsDontBackup\TargetingAndTracking\New' },
          :summary,
          :report_differences,
          :report_differing_charts,
        ]
      }
    }
  end

  def run_flat_dashboard(control)
    differing_pagess = {}

    control[:scenarios].each do |scenario|
      set_filenames(scenario)
      set_page_name(scenario)
      differing_pages = super(control)
      differing_pages.transform_keys!{ |k| :"#{k} #{@filename_type}" }
      differing_pagess.merge!(differing_pages)
    end

    differing_pagess
  end

  private

  def set_filenames(scenario)
    @filename_type = "TnT #{type(scenario)}"
  end

  def set_page_name(scenario)
    @page_type = "TnT #{type(scenario)}"
  end

  def type(scenario)
    "sd=#{scenario[:target_start_date]},ad=#{scenario[:truncate_amr_data]}"
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
