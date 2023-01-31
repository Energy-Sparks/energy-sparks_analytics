# frozen_string_literal: true

module Costs
  class MonthlyMeterCostsService
    def initialize(meter:)
      @meter = meter

      @non_rate_types = %i[days start_date end_date first_day month]
    end

    def calculate_costs
      calculate_monthly_cost_breakdowns
    end

    private

    def calculate_monthly_cost_breakdowns
      monthly_cost_breakdowns = []
      months_billing.each do |month_start_date, monthly_cost_breakdown|
        monthly_cost_breakdowns << costs_meter_month_for(month_start_date, monthly_cost_breakdown)
      end
      monthly_cost_breakdowns
    end

    def costs_meter_month_for(month_start_date, monthly_cost_breakdown)
      Costs::MeterMonth.new(
        month_start_date: month_start_date,
        start_date: monthly_cost_breakdown[:start_date],
        end_date: monthly_cost_breakdown[:end_date],
        bill_component_costs: monthly_cost_breakdown.except!(*@non_rate_types)
                                                    .transform_keys do |key|
                                                      key.to_s.parameterize.underscore.to_sym
                                                    end
      )
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    # Method adapted from MeterMonthlyCostsAdvice
    def months_billing
      months_billing = Hash.new do |hash, month|
        hash[month] = Hash.new do |h, bill_component_types|
          h[bill_component_types] = 0.0
        end
      end

      (@meter.amr_data.start_date..@meter.amr_data.end_date).each do |date|
        day1_month = date.beginning_of_month
        bill_component_costs = @meter.amr_data.accounting_tariff.bill_component_costs_for_day(date)
        bill_component_costs.each do |bill_type, cost_in_pounds_sterling|
          months_billing[day1_month][bill_type] += cost_in_pounds_sterling
        end
        # months_billing[day1_month][:days] += 1
        months_billing[day1_month][:start_date] = date unless months_billing[day1_month].key?(:start_date)
        months_billing[day1_month][:end_date]   = date
      end
      months_billing
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end
end
