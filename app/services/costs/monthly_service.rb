# frozen_string_literal: true

module Costs
  class MonthlyService
    def initialize(meter_collection:)
      @meter_collection = meter_collection

      @non_rate_types = %i[days start_date end_date first_day month]
    end

    def create_model
      meter_monthly_costs
    end

    private

    def last_day_of_month(date)
      if date.month == 12
        Date.new(date.year + 1, 1, 1) - 1
      else
        Date.new(date.year, date.month + 1, 1) - 1
      end
    end

    def meter_monthly_costs
      meter_costs = []
      @meter_collection.electricity_meters.each do |meter|
        meter_costs << OpenStruct.new(
            mpan_mprn: meter.mpan_mprn,
            meter_name: meter.name,
            monthly_accounts: calculate_monthly_accounts_for(meter)
            )
      end
      meter_costs
    end

    def first_day_of_month(date)
      Date.new(date.year, date.month, 1)
    end

    def calculate_monthly_accounts_for(meter)
      months_billing = Hash.new { |hash, month| hash[month] = Hash.new { |h, bill_component_types| h[bill_component_types] = 0.0 } }
      (meter.amr_data.start_date..meter.amr_data.end_date).each do |date|
        day1_month = first_day_of_month(date)
        bc = meter.amr_data.accounting_tariff.bill_component_costs_for_day(date)
        bc.each do |bill_type, £|
          months_billing[day1_month][bill_type] += £
        end
        months_billing[day1_month][:days] += 1
        months_billing[day1_month][:start_date] = date unless months_billing[day1_month].key?(:start_date)
        months_billing[day1_month][:end_date]   = date
      end

      # calculate totals etc.
      months_billing.each do |date, months_bill|
        months_bill[:total]      = months_bill.map { |type, £| @non_rate_types.include?(type) ? 0.0 : £ }.sum
        months_bill[:first_day]  = first_day_of_month(date)
        months_bill[:month]      = months_bill[:first_day].strftime('%b %Y')
      end

      # calculate change with 12 months before, unless not full (last) month
      months_billing.each_with_index do |(_day1_month, month_billing), month_index|
        next if month_index + 12 > months_billing.length - 1

        months_billing_plus_12 = months_billing.values[month_index + 12]
        full_month = last_day_of_month(months_billing_plus_12[:start_date]) == months_billing_plus_12[:end_date]
        months_billing_plus_12[:variance_versus_last_year] = full_month ? months_billing_plus_12[:total] - month_billing[:total] : nil
      end

      # label partial months
      months_billing.each do |_day1_month, month_billing|
        full_month = last_day_of_month(month_billing[:start_date]) == month_billing[:end_date]
        month_billing[:month] += ' (partial)' unless full_month
      end

      months_billing
    end
  end
end
