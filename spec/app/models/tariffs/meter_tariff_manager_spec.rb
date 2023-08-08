require 'spec_helper'

describe MeterTariffManager do

  let(:economic_tariff) {
    {
     :name=>"Economic standard electricity tariff (inc day-night)",
     :rates=>
      {
        :rate=> {:per=>:kwh, :rate=>0.15},
        :daytime_rate=>{:per=>:kwh, :rate=>0.16, :from=>TimeOfDay.new(6,30), :to=>TimeOfDay.new(24,00)},
        :nighttime_rate=>{:per=>:kwh, :rate=>0.12, :from=>TimeOfDay.new(0,0), :to=>TimeOfDay.new(6,30)}
      }
    }
  }

  let(:default) { false }
  let(:source)  { :manually_entered }
  let(:start_date) { Date.new(2000, 1, 1) }
  let(:end_date)  { Date.new(2050, 1, 1) }

  let(:accounting_tariff) {
    {
      :start_date=> start_date,
      :end_date=> end_date,
      :name=>"Electricity Accounting Tariff",
      :default=> default,
      :source => source,
      :system_wide=>false,
      :rates=> {
        :rate=>{:per=>:kwh, :rate=>0.15},
        :standing_charge=>{:per=>:day, :rate=>1.0}
      }
    }
  }

  let(:meter_attributes) {
    {:economic_tariff=> economic_tariff, :accounting_tariffs=> [accounting_tariff]}
  }

  let(:kwh_data_x48)       { Array.new(48, 0.01) }
  let(:amr_end_date)       { Date.new(2023,1,31) }
  let(:meter) { build(:meter,
      type: :electricity,
      meter_attributes: meter_attributes,
      amr_data: build(:amr_data, :with_days, day_count: 31, end_date: amr_end_date, kwh_data_x48: kwh_data_x48)
    )
  }

  let(:meter_tariff_manager)    { MeterTariffManager.new(meter) }

  context 'pre-processing' do
    context 'the accounting tariffs' do
      let(:tariff) { meter_tariff_manager.accounting_tariffs.first }
      it 'creates an AccountingTariff' do
        expect(tariff).to_not be_nil
        expect(tariff.fuel_type).to eq :electricity
        expect(tariff.tariff).to eq accounting_tariff
        expect(tariff.differential?(Date.today)).to eq false
      end
      context 'and its a default accounting tariff' do
        let(:default) { true }
        let(:tariff) { meter_tariff_manager.accounting_tariffs.first }
        it 'creates an AccountingTariff' do
          expect(tariff).to be_nil
        end
      end
    end
    context 'the economic tariffs' do
      let(:tariff) { meter_tariff_manager.economic_tariff }
      it 'creates an EconomicTariff' do
        expect(tariff).to_not be_nil
        expect(tariff.fuel_type).to eq :electricity
        expect(tariff.tariff).to eq economic_tariff
      end
    end
    context 'smart meter tariffs' do
      let(:source)  { :dcc }
      #set tariff to start after the meter data
      let(:start_date)  { Date.new(2023, 1, 15) }
      let(:tariff) { meter_tariff_manager.accounting_tariffs.first }
      it 'backdates the tariffs to the amr start date' do
        expect(tariff.tariff[:start_date]).to eq amr_end_date - 30
      end
    end
  end

  context '.economic_cost' do
    let(:economic_cost) { meter_tariff_manager.economic_cost(amr_end_date, kwh_data_x48)}
    it 'calculates the expected cost' do
      expect(economic_cost.differential_tariff?).to eq false
      expect(economic_cost.standing_charges).to eq({})
      expect(economic_cost.all_costs_x48['flat_rate']).to eq Array.new(48, 0.01 * 0.15)
    end
  end

  context '.accounting_cost' do
    let(:accounting_cost) { meter_tariff_manager.accounting_cost(amr_end_date, kwh_data_x48)}

    it 'calculates the expected cost' do
      expect(accounting_cost.differential_tariff?).to eq false
      expect(accounting_cost.standing_charges).to eq({standing_charge: 1.0})
      expect(accounting_cost.all_costs_x48['flat_rate']).to eq Array.new(48, 0.01 * 0.15)
    end

    context 'and there are multiple tariffs' do
      let(:start_date) { Date.new(2000, 1, 1) }
      let(:end_date)  { Date.new(2023, 1, 1) }

      let(:accounting_tariff2) {
        {
          :start_date=> Date.new(2023, 1, 2),
          :end_date=> Date.new(2023, 1, 31),
          :name=>"Current Electricity Accounting Tariff",
          :default=> default,
          :source => source,
          :system_wide=>false,
          :rates=> {
            :rate=>{:per=>:kwh, :rate=>0.30},
            :standing_charge=>{:per=>:day, :rate=>1.5}
          }
        }
      }

      let(:meter_attributes) {
        {:economic_tariff=> economic_tariff, :accounting_tariffs=> [accounting_tariff, accounting_tariff2]}
      }

      it 'selects the right tariff and calculates the expected cost' do
        expect(accounting_cost.differential_tariff?).to eq false
        expect(accounting_cost.standing_charges).to eq({standing_charge: 1.5})
        expect(accounting_cost.all_costs_x48['flat_rate']).to eq Array.new(48, 0.01 * 0.30)
      end

    end
  end

end
