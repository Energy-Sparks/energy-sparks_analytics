# frozen_string_literal: true

require_relative '../periods'

module Periods
  class FixedAcademicYear < YearPeriods
    protected

    def period_list(first_meter_date = @first_meter_date, last_meter_date = @last_meter_date)
      self.class.enumerator(first_meter_date, last_meter_date).map { |args| new_school_period(*args) }
    end

    def self.enumerator(start_date, end_date)
      Enumerator.new do |enumerator|
        # debugger
        period_end = end_date
        period_start = [start_date, Date.new(period_end.year, 9, 1)].max
        loop do
          if period_end >= period_start
            enumerator.yield [period_start, period_end]
            break if period_start == start_date
          end
          period_end = [end_date, Date.new(period_end.year, 8, 31)].min
          period_start = [start_date, period_start - 1.year].max
        end
      end
    end

    def calculate_period_from_date(_date)
      raise EnergySparksUnsupportedFunctionalityException, 'not implemented yet'
    end
  end
end
