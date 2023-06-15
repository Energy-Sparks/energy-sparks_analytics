# frozen_string_literal: true

require 'spec_helper'

describe AlertSolarPVBenefitEstimator do
  Object.const_set('Rails', true) # Otherwise the test fails at line 118 (RecordTestTimes) in ChartManager

  let(:school) { @acme_academy }
  let(:alert) { AlertSolarPVBenefitEstimator.new(school) }
  let(:default_pricing_template_variables) do
    {
      optimum_kwp: '70 kWp',
      optimum_payback_years: '6 years',
      optimum_mains_reduction_percent: '12%',
      one_year_saving_£current: '£9,000',
      relevance: 'relevant',
      analysis_date: '',
      status: '',
      rating: '5',
      term: '',
      bookmark_url: '',
      max_asofdate: '',
      pupils: '961',
      floor_area: '5,900 m2',
      school_type: 'secondary',
      school_name: 'Acme Academy',
      school_activation_date: '',
      school_creation_date: '2020-10-08',
      urn: '654321',
      one_year_saving_kwh: '57,000 kWh',
      one_year_saving_£: '£9,000',
      one_year_saving_co2: '12,000 kg CO2',
      ten_year_saving_co2: '120,000 kg CO2',
      average_one_year_saving_£: '£9,000',
      average_ten_year_saving_£: '£90,000',
      ten_year_saving_£: '£90,000',
      payback_years: '',
      average_payback_years: '6 years',
      capital_cost: '£53,000',
      average_capital_cost: '£53,000',
      timescale: 'year',
      time_of_year_relevance: '5',
      solar_pv_scenario_table: [['Capacity(kWp)',
                                 'Panels',
                                 'Area (m2)',
                                 'Annual self consumed solar electricity (kWh)',
                                 'Annual exported solar electricity (kWh)',
                                 'Annual output from panels (kWh)',
                                 'Reduction in mains consumption',
                                 'Annual saving',
                                 'Annual saving (CO2)',
                                 'Estimated cost',
                                 'Payback years'],
                                ['1',
                                 '3',
                                 '4',
                                 '880',
                                 '5.1',
                                 '880',
                                 '0.19%',
                                 '£140',
                                 '170',
                                 '£2,400',
                                 '18 years'],
                                ['2',
                                 '7',
                                 '10',
                                 '1,800',
                                 '10',
                                 '1,800',
                                 '0.37%',
                                 '£270',
                                 '330',
                                 '£3,200',
                                 '12 years'],
                                ['4',
                                 '13',
                                 '19',
                                 '3,500',
                                 '20',
                                 '3,500',
                                 '0.75%',
                                 '£540',
                                 '670',
                                 '£4,800',
                                 '9 years'],
                                ['8',
                                 '27',
                                 '39',
                                 '7,000',
                                 '41',
                                 '7,000',
                                 '1.5%',
                                 '£1,100',
                                 '1,300',
                                 '£7,900',
                                 '7 years'],
                                ['16',
                                 '53',
                                 '76',
                                 '14,000',
                                 '81',
                                 '14,000',
                                 '3%',
                                 '£2,200',
                                 '2,700',
                                 '£14,000',
                                 '6 years'],
                                ['32',
                                 '107',
                                 '154',
                                 '28,000',
                                 '200',
                                 '28,000',
                                 '6%',
                                 '£4,300',
                                 '5,300',
                                 '£26,000',
                                 '6 years'],
                                ['64',
                                 '213',
                                 '307',
                                 '53,000',
                                 '3,400',
                                 '56,000',
                                 '11%',
                                 '£8,300',
                                 '11,000',
                                 '£49,000',
                                 '6 years'],
                                ['70',
                                 '233',
                                 '336',
                                 '57,000',
                                 '4,600',
                                 '62,000',
                                 '12%',
                                 '£9,000',
                                 '12,000',
                                 '£53,000',
                                 '6 years'],
                                ['128',
                                 '427',
                                 '615',
                                 '91,000',
                                 '22,000',
                                 '110,000',
                                 '19%',
                                 '£15,000',
                                 '21,000',
                                 '£89,000',
                                 '6 years']]
    }
  end

  before(:all) do
    @acme_academy = load_unvalidated_meter_collection(school: 'acme-academy')
  end

  it 'calculates the alert for a given asof date' do
    current_pricing = BenchmarkMetrics.default_prices
    class_double('BenchmarkMetrics', pricing: current_pricing, default_prices: current_pricing).as_stubbed_const
    alert.calculate(Date.new(2022, 7, 12))
    expect(BenchmarkMetrics.pricing).to eq(current_pricing)
    expect(alert.text_template_variables).to eq(default_pricing_template_variables)
    expect(alert.text_template_variables[:one_year_saving_kwh]).to eq('57,000 kWh')
    expect(alert.text_template_variables[:one_year_saving_£current]).to eq('£9,000')
    expect(alert.text_template_variables[:one_year_saving_£]).to eq('£9,000')
    expect(alert.text_template_variables[:average_one_year_saving_£]).to eq('£9,000')
    expect(alert.text_template_variables[:average_ten_year_saving_£]).to eq('£90,000')
    expect(alert.text_template_variables[:ten_year_saving_£]).to eq('£90,000')
    expect(alert.text_template_variables[:capital_cost]).to eq('£53,000')
    expect(alert.text_template_variables[:average_capital_cost]).to eq('£53,000')

    new_pricing = OpenStruct.new(gas_price: 0.06, electricity_price: 0.3, solar_export_price: 0.1)
    class_double('BenchmarkMetrics', pricing: new_pricing, default_prices: new_pricing).as_stubbed_const
    expect(BenchmarkMetrics.pricing).to eq(new_pricing)
    alert.calculate(Date.new(2022, 7, 12))
    expect(alert.text_template_variables).not_to eq(default_pricing_template_variables)
    expect(alert.text_template_variables[:one_year_saving_£current]).to eq('£29,000')
    expect(alert.text_template_variables[:one_year_saving_£]).to eq('£29,000')
    expect(alert.text_template_variables[:average_one_year_saving_£]).to eq('£29,000')
    expect(alert.text_template_variables[:average_ten_year_saving_£]).to eq('£290,000')
    expect(alert.text_template_variables[:ten_year_saving_£]).to eq('£290,000')
    expect(alert.text_template_variables[:capital_cost]).to eq('£140,000')
    expect(alert.text_template_variables[:average_capital_cost]).to eq('£140,000')
  end
end
