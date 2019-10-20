class BenchmarkChartConfigs
=begin
  EXAMPLE = {
  benchmark_electricy_out_of_hours:  {
    name:             'Benchmark out of hours electricity comparison for Sheffield',
    chart1_type:      :bar,
    chart1_subtype:   :stacked,
    columns_headings:  { key: 'School', data: [ 'Holidays', 'Weekends', 'School Day Open', 'School day closed' ] }
    sql:  "
      select s.school_name, 
              al.holidays_percent, 
              al.weekends_percent, 
              al.schoolday_open_percent, 
              al.schoolday_closed_percent
      from school s, alerts al
      where s.school_id = ai.school_id
        and ai.alert_type = 'AlertOutOfHoursBaseUsage'
        and s.area_name = 'Sheffield'
      group by s.school_name having al.date = max(al.date)
      sort by al.schoolday_open_percent desc
    "
  },
  schoolday_open_percent:   { description: 'Annual school day open percent usage',    units: :percent },
  schoolday_open_percent:   {
    description: 'Annual school day open percent usage',
    benchmark_variable:     true,
    units: :percent
  },
}
=end
end