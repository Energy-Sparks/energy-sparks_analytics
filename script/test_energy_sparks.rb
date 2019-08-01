# framework for analytics testing
#

test_instructions = {
  log_filename: './HHH/xyz' + DateTime.now.to_s + '.log',
  amr_data: {
    feeds: {
      dark_sky: true,
      grid_carbon_intensity:  true,
      sheffield_solar_pv: true
    },
    load_and_validate_raw_data: {
      bulk_source_filename: './AAAAA/amr.csv',
      split_bulk_file_to_directory: { save_to: './BBBBB' },
      validate: { school_names:  '*' },
      save_validated_data_to: './CCCCC'
    }
  },
  load_validated_data: { school_names: '*' },
  run_charts_and_advice: {
    all_default_charts: true,
    single_page: [ :page1, :page4 ],
    single_chart: { tab1: [ :chart1, chart2 ], tab2: [ :chart3, :chart4 ] },
    convert_charts_to_different_units:  { unit: :£, filename_suffix: ' - economic costs' },
    benchmark_times:   { comparison_filename: './DDD/qqq.csv', result_filename:  './DDD/zzz.csv'},
    benchmark_memory:  { comparison_filename: './DDD/sss.csv', result_filename:  './DDD/ttt.csv'},
    compare_results:   { comparison_directory: './EEEE', result_directory: './FFFFF' }
  },
  run_alerts: {
    alerts:             '*',
    asof_date:          Date.new(2019, 7, 22),
    output:             [ :template_data, :alert_variables ],
    school_names:       '*',
    compare_results:   { comparison_directory: './EEEE', result_directory: './FFFFF' },
    benchmark_times:   { comparison_filename: './DDD/qqq.csv', result_filename:  './DDD/zzz.csv'},
    benchmark:         { archive: true, filename: './JJJ/SSS.csv'
  }
}

