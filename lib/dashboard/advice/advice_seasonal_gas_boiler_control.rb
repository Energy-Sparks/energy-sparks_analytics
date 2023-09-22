class AdviceGasBoilerSeasonalControl
  def self.warm_weather_on_days_adjective(days)
    I18nHelper.adjective( warm_weather_on_days_rating(days)[:adjective] )
  end

  def self.warm_weather_on_days_rating(days)
    range = {
      0..6     => { adjective: :excellent,      rating_value: 10  },
      6..11    => { adjective: :good,           rating_value:  8  },
      12..16   => { adjective: :above_average,  rating_value:  4  },
      17..24   => { adjective: :poor,           rating_value:  2  },
      25..365  => { adjective: :very_poor,      rating_value:  0  }
    }

    range.select { |k, _v| k.cover?(days.to_i) }.values.first
  end
end
