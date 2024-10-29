# frozen_string_literal: true

module Corrections
  module ZeroNegative
    def self.apply(amr_data)
      amr_data.each do |date, reading|
        next unless reading.kwh_data_x48.any?(&:negative?)

        data = reading.kwh_data_x48.map { |v| [v, 0.0].max }
        amr_data.add(date, OneDayAMRReading.new(reading.meter_id, date, 'SOLC', nil, DateTime.now, data))
      end
    end
  end
end
