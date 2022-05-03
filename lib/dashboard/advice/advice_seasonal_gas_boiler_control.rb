class AdviceGasBoilerSeasonalControl < AdviceBoilerHeatingBase
  include Logging

  def enough_data
    aggregate_meter.amr_data.days > 364 && valid_model? ? :enough : :not_enough
  end

  def raw_content(user_type: nil)
    charts_and_html = []

    charts_and_html.push( { type: :html,        content: "<h2>Seasonal Control</h2>" } )
    charts_and_html += debug_content
    charts_and_html.push( { type: :html,        content: introduction } )
    charts_and_html.push( { type: :chart_name,  content: breakdown_chart_name } )
    charts_and_html.push( { type: :html,        content: chart_explanation } )

    charts_and_html
  end

  def self.warm_weather_on_days_adjective(days)
    warm_weather_on_days_rating(days)[:adjective]
  end

  def self.warm_weather_on_days_rating(days)
    range = {
      0..6     => { adjective: 'excellent',      rating_value: 10  },
      6..11    => { adjective: 'good',           rating_value:  8  },
      12..16   => { adjective: 'above average',  rating_value:  4  },
      17..24   => { adjective: 'poor',           rating_value:  2  },
      25..365  => { adjective: 'very poor',      rating_value:  0  }
    }

    range.select { |k, _v| k.cover?(days.to_i) }.values.first
  end

  private

  def breakdown_chart_name
    self.class.config[:charts][0]
  end

  def heating_on_off_by_week_chart # TODO(PH, 26Apr2022) deprecate
    charts[0]
  end

  def introduction
    days = number_days_heating_on_in_warm_weather

    text = %{
      <p>
        <%= @school.name %> has had its heating on for <%= days.to_i %> days
        in warm weather in the last year which is <%= self.class.warm_weather_on_days_adjective(days) %>.
      </p>
      <p>
        Your school could save up to
        <%= formatted_impact(:£) %>,
        <%= formatted_impact(:co2) %> or
        <%= formatted_impact(:kwh) %>
        by turning its boiler off in warm weather,
        for example earlier in the Spring and later in the Autumn.
      <p>
    }

    ERB.new(text).result(binding)
  end

  def chart_explanation
    %{
      The chart above shows when the heating and hot water was on in the last year,
      including when the heating was left on in warm weather. You can drill-down to
      individual days by clicking on the bars on the chart.
    }
  end

  def formatted_impact(data_type)
    FormatEnergyUnit.format(data_type, impact(data_type), :html)
  end

  def impact(data_type)
    aggregate_analysis(:heating_warm_weather, data_type)
  end

  def number_days_heating_on_in_warm_weather
    aggregate_analysis(:heating_warm_weather, :days)
  end

  def aggregate_analysis(heating_type, value_type)
    seasonal_analysis.values.map do |by_heating_regime_data|
      by_heating_regime_data.dig(heating_type, value_type)
    end.compact.sum
  end

  def seasonal_analysis
    @seasonal_analysis ||= heating_model.heating_on_seasonal_analysis
  end

  def meter
    @school.aggregated_heat_meters
  end

  def heating_model
    @heating_model ||= calculate_heating_model
  end

  def valid_model?
    heating_model
    true
  rescue EnergySparksNotEnoughDataException => e
    logger.info "Not running #{self.class.name} because model hant fitted"
    logger.info e.message
    false
  end

  def calculate_heating_model
    start_date = [meter.amr_data.end_date - 365, meter.amr_data.start_date].max
    last_year = SchoolDatePeriod.new(:analysis, 'validate amr', start_date, meter.amr_data.end_date)
    meter.heating_model(last_year)
  end
end
