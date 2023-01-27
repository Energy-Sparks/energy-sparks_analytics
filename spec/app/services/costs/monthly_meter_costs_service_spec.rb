# frozen_string_literal: true

require 'spec_helper'

describe Costs::MonthlyMeterCostsService do
  let(:service) { Costs::MonthlyMeterCostsService.new(meter: @acme_academy.electricity_meters.first) } # 1591058886735

  # using before(:all) here to avoid slow loading of YAML and then
  # running the aggregation code for each test.
  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  context '#create_model' do
    it 'creates a model for results of a costs analysis' do
      model = service.create_model
      expect(model.count).to eq(43)
      expect(model.first.month_start_date).to eq(Date.parse('2019-01-01'))
      expect(model.first.start_date).to eq(Date.parse('2019-01-13'))
      expect(model.first.end_date).to eq(Date.parse('2019-01-31'))
      expect(model.first.bill_component_costs.keys.sort).to eq(%i[flat_rate standing_charge])
      expect(model.first.bill_component_costs[:flat_rate]).to round_to_two_digits(1554.26) # 1554.2571449999998
      expect(model.first.bill_component_costs[:standing_charge]).to round_to_two_digits(19.0) # 19.0
      expect(model.first.full_month).to eq(false)
      expect(model.first.total).to eq(model.first.bill_component_costs[:flat_rate] + model.first.bill_component_costs[:standing_charge])

      expect(model.last.month_start_date).to eq(Date.parse('2022-07-01'))
      expect(model.last.start_date).to eq(Date.parse('2022-07-01'))
      expect(model.last.end_date).to eq(Date.parse('2022-07-13'))
      expect(model.last.bill_component_costs.keys.sort).to eq(%i[flat_rate standing_charge])
      expect(model.last.bill_component_costs[:flat_rate]).to round_to_two_digits(394.83) # 394.83000000000004
      expect(model.last.bill_component_costs[:standing_charge]).to round_to_two_digits(13.0) # 13.0
      expect(model.last.full_month).to eq(false)
      expect(model.last.total).to eq(model.last.bill_component_costs[:flat_rate] + model.last.bill_component_costs[:standing_charge])

      # Tests for last years electricty bill components
      last_years_electricity_bill_components = model.select { |m| m.month_start_date > Date.new(2021,6,30) && m.month_start_date < Date.new(2022,8,1) }
      expect(last_years_electricity_bill_components.size).to eq(13)
      expect(last_years_electricity_bill_components[0].month_start_date.strftime('%b %Y')).to eq('Jul 2021')
      expect(last_years_electricity_bill_components[0].start_date.to_s).to eq('2021-07-01')
      expect(last_years_electricity_bill_components[0].end_date.to_s).to eq('2021-07-31')
      expect(last_years_electricity_bill_components[0].days).to eq(31)
      expect(last_years_electricity_bill_components[0].full_month).to eq(true)
      expect(last_years_electricity_bill_components[0].bill_component_costs.keys.sort).to eq([:flat_rate, :standing_charge])
      expect(last_years_electricity_bill_components[0].bill_component_costs[:flat_rate]).to round_to_two_digits(715.35) # 715.35
      expect(last_years_electricity_bill_components[0].bill_component_costs[:standing_charge]).to round_to_two_digits(31.0) # 31.0
      expect(last_years_electricity_bill_components[0].total).to round_to_two_digits(746.35) # 746.35

      expect(last_years_electricity_bill_components[1].month_start_date.strftime('%b %Y')).to eq('Aug 2021')
      expect(last_years_electricity_bill_components[1].start_date.to_s).to eq('2021-08-01')
      expect(last_years_electricity_bill_components[1].end_date.to_s).to eq('2021-08-31')
      expect(last_years_electricity_bill_components[1].days).to eq(31)
      expect(last_years_electricity_bill_components[1].full_month).to eq(true)
      expect(last_years_electricity_bill_components[1].bill_component_costs.keys.sort).to eq([:flat_rate, :standing_charge])
      expect(last_years_electricity_bill_components[1].bill_component_costs[:flat_rate]).to round_to_two_digits(475.81) # 475.81499999999994 
      expect(last_years_electricity_bill_components[1].bill_component_costs[:standing_charge]).to round_to_two_digits(31.0) # 31.0
      expect(last_years_electricity_bill_components[1].total).to round_to_two_digits(506.81) # 506.81499999999994

      expect(last_years_electricity_bill_components[2].month_start_date.strftime('%b %Y')).to eq('Sep 2021')
      expect(last_years_electricity_bill_components[2].start_date.to_s).to eq('2021-09-01')
      expect(last_years_electricity_bill_components[2].end_date.to_s).to eq('2021-09-30')
      expect(last_years_electricity_bill_components[2].days).to eq(30)
      expect(last_years_electricity_bill_components[2].full_month).to eq(true)
      expect(last_years_electricity_bill_components[2].bill_component_costs.keys.sort).to eq([:flat_rate, :standing_charge])
      expect(last_years_electricity_bill_components[2].bill_component_costs[:flat_rate]).to round_to_two_digits(1237.29) # 1237.2899999999997
      expect(last_years_electricity_bill_components[2].bill_component_costs[:standing_charge]).to round_to_two_digits(30.0) # 30.0
      expect(last_years_electricity_bill_components[2].total).to round_to_two_digits(1267.29) # 1267.2899999999997 

      expect(last_years_electricity_bill_components[3].month_start_date.strftime('%b %Y')).to eq('Oct 2021')
      expect(last_years_electricity_bill_components[3].start_date.to_s).to eq('2021-10-01')
      expect(last_years_electricity_bill_components[3].end_date.to_s).to eq('2021-10-31')
      expect(last_years_electricity_bill_components[3].days).to eq(31)
      expect(last_years_electricity_bill_components[3].full_month).to eq(true)
      expect(last_years_electricity_bill_components[3].bill_component_costs.keys.sort).to eq([:flat_rate, :standing_charge])
      expect(last_years_electricity_bill_components[3].bill_component_costs[:flat_rate]).to round_to_two_digits(1202.76) # 1202.76
      expect(last_years_electricity_bill_components[3].bill_component_costs[:standing_charge]).to round_to_two_digits(31) # 31.0
      expect(last_years_electricity_bill_components[3].total).to round_to_two_digits(1233.76) # 1233.76

      expect(last_years_electricity_bill_components[4].month_start_date.strftime('%b %Y')).to eq('Nov 2021')
      expect(last_years_electricity_bill_components[4].start_date.to_s).to eq('2021-11-01')
      expect(last_years_electricity_bill_components[4].end_date.to_s).to eq('2021-11-30')
      expect(last_years_electricity_bill_components[4].days).to eq(30)
      expect(last_years_electricity_bill_components[4].full_month).to eq(true)
      expect(last_years_electricity_bill_components[4].bill_component_costs.keys.sort).to eq([:flat_rate, :standing_charge])
      expect(last_years_electricity_bill_components[4].bill_component_costs[:flat_rate]).to round_to_two_digits(1791.16) # 1791.1649999999995
      expect(last_years_electricity_bill_components[4].bill_component_costs[:standing_charge]).to round_to_two_digits(30.0) # 30.0
      expect(last_years_electricity_bill_components[4].total).to round_to_two_digits(1821.16) # 1821.1649999999995

      expect(last_years_electricity_bill_components[5].month_start_date.strftime('%b %Y')).to eq('Dec 2021')
      expect(last_years_electricity_bill_components[5].start_date.to_s).to eq('2021-12-01')
      expect(last_years_electricity_bill_components[5].end_date.to_s).to eq('2021-12-31')
      expect(last_years_electricity_bill_components[5].days).to eq(31)
      expect(last_years_electricity_bill_components[5].full_month).to eq(true)
      expect(last_years_electricity_bill_components[5].bill_component_costs.keys.sort).to eq([:flat_rate, :standing_charge])
      expect(last_years_electricity_bill_components[5].bill_component_costs[:flat_rate]).to round_to_two_digits(1519.29) # 1519.2899999999995 
      expect(last_years_electricity_bill_components[5].bill_component_costs[:standing_charge]).to round_to_two_digits(31.0) # 
      expect(last_years_electricity_bill_components[5].total).to round_to_two_digits(1550.29) # 1550.2899999999995

      expect(last_years_electricity_bill_components[6].month_start_date.strftime('%b %Y')).to eq('Jan 2022')
      expect(last_years_electricity_bill_components[6].start_date.to_s).to eq('2022-01-01')
      expect(last_years_electricity_bill_components[6].end_date.to_s).to eq('2022-01-31')
      expect(last_years_electricity_bill_components[6].days).to eq(31)
      expect(last_years_electricity_bill_components[6].full_month).to eq(true)
      expect(last_years_electricity_bill_components[6].bill_component_costs.keys.sort).to eq([:flat_rate, :standing_charge])
      expect(last_years_electricity_bill_components[6].bill_component_costs[:flat_rate]).to round_to_two_digits(1996.17) # 1996.1700000000005
      expect(last_years_electricity_bill_components[6].bill_component_costs[:standing_charge]).to round_to_two_digits(31.0) # 31.0
      expect(last_years_electricity_bill_components[6].total).to round_to_two_digits(2027.17) # 2027.1700000000005

      expect(last_years_electricity_bill_components[7].month_start_date.strftime('%b %Y')).to eq('Feb 2022')
      expect(last_years_electricity_bill_components[7].start_date.to_s).to eq('2022-02-01')
      expect(last_years_electricity_bill_components[7].end_date.to_s).to eq('2022-02-28')
      expect(last_years_electricity_bill_components[7].days).to eq(28)
      expect(last_years_electricity_bill_components[7].full_month).to eq(true)
      expect(last_years_electricity_bill_components[7].bill_component_costs.keys.sort).to eq([:flat_rate, :standing_charge])
      expect(last_years_electricity_bill_components[7].bill_component_costs[:flat_rate]).to round_to_two_digits(1474.95) # 1474.9499999999998
      expect(last_years_electricity_bill_components[7].bill_component_costs[:standing_charge]).to round_to_two_digits(28.0) # 
      expect(last_years_electricity_bill_components[7].total).to round_to_two_digits(1502.95) # 1502.9499999999998

      expect(last_years_electricity_bill_components[8].month_start_date.strftime('%b %Y')).to eq('Mar 2022')
      expect(last_years_electricity_bill_components[8].start_date.to_s).to eq('2022-03-01')
      expect(last_years_electricity_bill_components[8].end_date.to_s).to eq('2022-03-31')
      expect(last_years_electricity_bill_components[8].days).to eq(31)
      expect(last_years_electricity_bill_components[8].full_month).to eq(true)
      expect(last_years_electricity_bill_components[8].bill_component_costs.keys.sort).to eq([:flat_rate, :standing_charge])
      expect(last_years_electricity_bill_components[8].bill_component_costs[:flat_rate]).to round_to_two_digits(1673.79) # 1673.79
      expect(last_years_electricity_bill_components[8].bill_component_costs[:standing_charge]).to round_to_two_digits(31.0) # 31.0
      expect(last_years_electricity_bill_components[8].total).to round_to_two_digits(1704.79) # 1704.79

      expect(last_years_electricity_bill_components[9].month_start_date.strftime('%b %Y')).to eq('Apr 2022')
      expect(last_years_electricity_bill_components[9].start_date.to_s).to eq('2022-04-01')
      expect(last_years_electricity_bill_components[9].end_date.to_s).to eq('2022-04-30')
      expect(last_years_electricity_bill_components[9].days).to eq(30)
      expect(last_years_electricity_bill_components[9].full_month).to eq(true)
      expect(last_years_electricity_bill_components[9].bill_component_costs.keys.sort).to eq([:flat_rate, :standing_charge])
      expect(last_years_electricity_bill_components[9].bill_component_costs[:flat_rate]).to round_to_two_digits(1029.84) # 1029.84
      expect(last_years_electricity_bill_components[9].bill_component_costs[:standing_charge]).to round_to_two_digits(30.0) # 30.0
      expect(last_years_electricity_bill_components[9].total).to round_to_two_digits(1059.84) # 1059.84

      expect(last_years_electricity_bill_components[10].month_start_date.strftime('%b %Y')).to eq('May 2022')
      expect(last_years_electricity_bill_components[10].start_date.to_s).to eq('2022-05-01')
      expect(last_years_electricity_bill_components[10].end_date.to_s).to eq('2022-05-31')
      expect(last_years_electricity_bill_components[10].days).to eq(31)
      expect(last_years_electricity_bill_components[10].full_month).to eq(true)
      expect(last_years_electricity_bill_components[10].bill_component_costs.keys.sort).to eq([:flat_rate, :standing_charge])
      expect(last_years_electricity_bill_components[10].bill_component_costs[:flat_rate]).to round_to_two_digits(1018.76) # 1018.7550000000001
      expect(last_years_electricity_bill_components[10].bill_component_costs[:standing_charge]).to round_to_two_digits(31.0) # 31.0
      expect(last_years_electricity_bill_components[10].total).to round_to_two_digits(1049.76) # 1049.755

      expect(last_years_electricity_bill_components[11].month_start_date.strftime('%b %Y')).to eq('Jun 2022')
      expect(last_years_electricity_bill_components[11].start_date.to_s).to eq('2022-06-01')
      expect(last_years_electricity_bill_components[11].end_date.to_s).to eq('2022-06-30')
      expect(last_years_electricity_bill_components[11].days).to eq(30)
      expect(last_years_electricity_bill_components[11].full_month).to eq(true)
      expect(last_years_electricity_bill_components[11].bill_component_costs.keys.sort).to eq([:flat_rate, :standing_charge])
      expect(last_years_electricity_bill_components[11].bill_component_costs[:flat_rate]).to round_to_two_digits(854.21) # 854.2050000000002
      expect(last_years_electricity_bill_components[11].bill_component_costs[:standing_charge]).to round_to_two_digits(30.0) # 30.0
      expect(last_years_electricity_bill_components[11].total).to round_to_two_digits(884.21) # 884.2050000000002

      expect(last_years_electricity_bill_components[12].month_start_date.strftime('%b %Y')).to eq('Jul 2022')
      expect(last_years_electricity_bill_components[12].start_date.to_s).to eq('2022-07-01')
      expect(last_years_electricity_bill_components[12].end_date.to_s).to eq('2022-07-13')
      expect(last_years_electricity_bill_components[12].days).to eq(13)
      expect(last_years_electricity_bill_components[12].full_month).to eq(false)
      expect(last_years_electricity_bill_components[12].bill_component_costs.keys.sort).to eq([:flat_rate, :standing_charge])
      expect(last_years_electricity_bill_components[12].bill_component_costs[:flat_rate]).to round_to_two_digits(394.83) # 394.83000000000004
      expect(last_years_electricity_bill_components[12].bill_component_costs[:standing_charge]).to round_to_two_digits(13.0) # 13.0
      expect(last_years_electricity_bill_components[12].total).to round_to_two_digits(407.83) # 407.83000000000004
    end
  end
end
