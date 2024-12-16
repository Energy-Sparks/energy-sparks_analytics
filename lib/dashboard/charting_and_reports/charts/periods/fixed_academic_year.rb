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
        period_end = end_date
        while true
          if period_end >= Date.new(period_end.year, 9, 1)
            enumerator.yield [Date.new(period_end.year, 9, 1), period_end]
            period_end = Date.new(period_end.year, 8, 31)
          elsif Date.new(period_end.year - 1, 9, 1) < start_date
            enumerator.yield [start_date, period_end]
            break
          else
            enumerator.yield [Date.new(period_end.year - 1, 9, 1), period_end]
            period_end = Date.new(period_end.year - 1, 8, 31)
          end
        end
      end
    end

    def calculate_period_from_date(_date)
      raise EnergySparksUnsupportedFunctionalityException, 'not implemented yet'
    end
  end
end
