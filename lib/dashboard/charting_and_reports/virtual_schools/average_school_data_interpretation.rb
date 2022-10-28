class AverageSchoolData
  def introduction_to_benchmark_and_exemplar_charts
    html = %(
      <p>
        The chart below provides a comparison with
        &apos;benchmark&apos; and &apos;exemplar&apos; schools,
        allowing you to see how your school compares with other energy
        efficient schools. You can click on the chart to drilldown to
        individual days and work out at what times of day and year
        your school is doing either better or worse than these schools.
      </p>
    )
    ERB.new(html).result(binding)
  end

  def introduction_to_intraday_benchmark_and_exemplar_charts
    html = %(
      <p>
        The chart below provides a comparison of your school&apos;s consumption
        during school days with
        &apos;benchmark&apos; and &apos;exemplar&apos; schools,
        allowing you to see how your school compares with other energy
        efficient schools. You can click on the chart to drilldown to
        individual days and work out at what times of day and year
        your school is doing either better or worse than these schools.
      </p>
    )
    ERB.new(html).result(binding)
  end

  def benchmark_and_exemplar_rankings(school)
    html = %(
      <p>
        A &apos;benchmark&apos; school represents the
        <%= average_school_percent_html(:benchmark) %> best ranked <%= school.school_type.humanize.downcase %> schools
        and &apos;exemplar&apos; the
        <%= average_school_percent_html(:exemplar) %> best <%= school.school_type.humanize.downcase %> schools.
      </p>
    )
    ERB.new(html).result(binding)
  end

  def addendum_to_benchmark_and_exemplar_charts
    html = %(
      <p>
        Look at the chart carefully, at what time of year and day is
        your school above the chart - is there something you
        can do like turning equipment off to reduce your consumption
        to match these schools? Are there any anomalies like jumps
        in usage outside school hours which you can&apos;t account for?
      <p>
    )
    ERB.new(html).result(binding)
  end

  def addendum_to_intraday_benchmark_and_exemplar_charts
    html = %(
      <p>
        Look at the chart carefully, at what time of day is
        your school above the chart - is there something you
        can do like turning equipment off to reduce your consumption
        to match these schools? Are there any anomalies like jumps
        in usage outside school hours which you can&apos;t account for?
      <p>
    )
    ERB.new(html).result(binding)
  end

  private

  def average_school_percent(benchmark_type)
    benchmark_range = benchmark_calculation_config[benchmark_type]
    (benchmark_range.first + benchmark_range.last) / 2.0
  end

  def average_school_percent_html(benchmark_type)
    FormatEnergyUnit.percent_to_1_dp(average_school_percent(benchmark_type))
  end
end
