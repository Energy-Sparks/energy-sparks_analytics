require 'spec_helper'

describe GenericAccountingTariff do

  let(:end_date)          { Date.today }
  let(:start_date)        { Date.today - 30 }
  let(:tariff_type)       { :flat }
  let(:rates)             { create_flat_rate }
  let(:kwh_data_x48)      { Array.new(48, 0.01) }

  let(:tariff_attribute) { create_accounting_tariff_generic(start_date: start_date, end_date: end_date, type: tariff_type, rates: rates) }

  let(:meter) { double(:meter) }

  let(:accounting_tariff)      { GenericAccountingTariff.new(meter, tariff_attribute) }

  before(:each) do
    expect(meter).to receive(:mpxn).and_return(1512345678900)
    expect(meter).to receive(:amr_data).and_return(nil)
    expect(meter).to receive(:fuel_type).and_return(:electricity)
  end

  context '.initialize' do
    context 'with overlapping times ranges' do
      let(:rates) {
        {
          rate0: {
            from: TimeOfDay.new(10,0),
            to: TimeOfDay.new(23,30),
            per: :kwh,
            rate: 0.15
          },
          rate1: {
            from: TimeOfDay.new(0,0),
            to: TimeOfDay.new(10,30),
            per: :kwh,
            rate: 0.15
          }
        }
      }
      let(:tariff_attribute) { create_accounting_tariff_generic(type: :differential, rates: rates) }
      it 'raises exception' do
        expect{ accounting_tariff }.to raise_error(AccountingTariff::OverlappingTimeRanges)
      end
    end

    context 'with incomplete time ranges' do
      let(:rates) {
        {
          rate0: {
            from: TimeOfDay.new(10,0),
            to: TimeOfDay.new(23,30),
            per: :kwh,
            rate: 0.15
          }
        }
      }

      let(:tariff_attribute) { create_accounting_tariff_generic(type: :differential, rates: rates) }
      it 'raises exception' do
        expect{ accounting_tariff }.to raise_error(AccountingTariff::IncompleteTimeRanges)
      end
    end

    context 'with times not on half hours' do
      let(:rates) {
        {
          rate0: {
            from: TimeOfDay.new(7,15),
            to: TimeOfDay.new(23,30),
            per: :kwh,
            rate: 0.15
          },
          rate1: {
            from: TimeOfDay.new(0,0),
            to: TimeOfDay.new(7,00),
            per: :kwh,
            rate: 0.15
          }
        }
      }
      let(:tariff_attribute) { create_accounting_tariff_generic(type: :differential, rates: rates) }
      it 'raises exception' do
        expect{ accounting_tariff }.to raise_error(AccountingTariff::TimeRangesNotOn30MinuteBoundary)
      end
    end
  end

  context '.differential?' do
    context 'with flat rate' do
      it 'identifies the type of tariff' do
        expect(accounting_tariff.differential?(nil)).to be false
        expect(accounting_tariff.flat_tariff?(nil)).to be true
      end
    end
    context 'with differential ' do
      let(:tariff_attribute) { create_accounting_tariff_generic(rates: create_differential_rate) }
      it 'identifies the type of tariff' do
        expect(accounting_tariff.differential?(nil)).to be true
        expect(accounting_tariff.flat_tariff?(nil)).to be false
      end
    end
  end

  context '.default?' do
    let(:tariff_attribute) { create_accounting_tariff_generic(tariff_holder: :school) }
    context 'when default is not not set' do
      it 'treats school tariffs as not default' do
        expect(accounting_tariff.default?).to be false
      end
    end
    context 'when default explicitly set to true' do
      let(:tariff_attribute) { create_accounting_tariff_generic(default: true) }
      it 'returns true' do
        expect(accounting_tariff.default?).to be true
      end
    end

    context 'when tariff holder is a school group' do
      let(:tariff_attribute) { create_accounting_tariff_generic(tariff_holder: :school_group) }

      it 'returns true' do
        expect(accounting_tariff.default?).to be true
      end
    end
  end

  context '.system_wide?' do
    let(:tariff_attribute) { create_accounting_tariff_generic(tariff_holder: :school) }
    context 'when not set' do
      it 'returns false' do
        expect(accounting_tariff.system_wide?).to be false
      end
    end
    context 'when explicitly set to true' do
      let(:tariff_attribute) { create_accounting_tariff_generic(system_wide: true) }
      it 'returns true' do
        expect(accounting_tariff.system_wide?).to be true
      end
    end

    context 'when tariff holder is site settings' do
      let(:tariff_attribute) { create_accounting_tariff_generic(tariff_holder: :site_settings) }

      it 'returns true' do
        expect(accounting_tariff.system_wide?).to be true
      end
    end
  end

  context '.costs' do
    let(:accounting_cost)  { accounting_tariff.costs(end_date, kwh_data_x48) }

    context 'with flat rate' do
      it 'calculates the expected cost' do
        expect(accounting_cost[:differential]).to eq false
        expect(accounting_cost[:standing_charges]).to eq({})
        expect(accounting_cost[:rates_x48]['flat_rate']).to eq Array.new(48, 0.01 * 0.15)
      end

      context 'with a standing charge when available' do
        let(:rates) { create_flat_rate(rate: 0.15, standing_charge: 1.0) }
        it 'includes the charge' do
          expect(accounting_cost[:standing_charges]).to eq({standing_charge: 1.0})
        end
      end

      context 'with a kwh based standing charge' do
        let(:levy_rate) { 0.6 }
        let(:other_charges) {
          {
            feed_in_tariff_levy: {
              per: :kwh,
              rate: levy_rate
            }
          }
        }
        let(:rates) { create_flat_rate(other_charges: other_charges) }
        it 'includes the charge' do
          expect(accounting_cost[:rates_x48]['Feed in tariff levy']).to eq Array.new(48, 0.01 * levy_rate)
        end
      end

      context 'with climate change levy' do
        let(:tariff_attribute) { create_accounting_tariff_generic(start_date: start_date, end_date: end_date,
          type: tariff_type, climate_change_levy: true, rates: rates) }

        it 'includes the charge' do
          #value is from ClimateChangeLevy
          expect(accounting_cost[:rates_x48][:climate_change_levy__2023_24]).to eq Array.new(48, 0.01 * 0.00775)
        end
      end

      context 'with duos charges' do
        let(:other_charges) {
          {
            duos_red: 0.025,
            duos_amber: 0.015,
            duos_green: 0.01
          }
        }
        let(:rates) { create_flat_rate(other_charges: other_charges) }
        it 'includes the charges' do
          #check it calculates and we have non-zero values for each period
          expect(accounting_cost[:rates_x48][:duos_green].sum).to_not be 0.0
          expect(accounting_cost[:rates_x48][:duos_amber].sum).to_not be 0.0
          expect(accounting_cost[:rates_x48][:duos_green].sum).to_not be 0.0
        end
      end

      context 'with tnuous charge' do
        let(:other_charges) {
          {
            tnuos: true
          }
        }
        let(:rates) { create_flat_rate(other_charges: other_charges) }
        #let(:start_date) {Date.new(2022,1,1)}
        #let(:end_date)   {Date.new(2022,3,15)}

        #TODO: this currently doesn't work as the tnuos config is out of date
        xit 'includes the charge as a standing charge' do
          puts accounting_cost.inspect
        end
      end

      context 'with other standing charges' do
        let(:other_charges) {
          {
            data_collection_dcda_agent_charge: {
              per: :day,
              rate: 0.5
            }
          }
        }
        let(:rates) { create_flat_rate(other_charges: other_charges) }
        it 'adds them to standing charges' do
          expect(accounting_cost[:standing_charges][:data_collection_dcda_agent_charge]).to eq(0.5)
        end
      end
    end

    context 'with differential rate' do
      let(:tariff_type) { :differential }
      let(:rates) { create_differential_rate(day_rate: 0.30, night_rate: 0.15, standing_charge: nil) }

      it 'calculates the expected cost' do
        expect(accounting_cost[:differential]).to eq true
        expect(accounting_cost[:standing_charges]).to eq({})
        expect(accounting_cost[:rates_x48]['07:00 to 23:30']).to eq Array.new(14, 0.0) + Array.new(34, 0.01 * 0.15)
        expect(accounting_cost[:rates_x48]['00:00 to 06:30']).to eq Array.new(14, 0.01 * 0.30) + Array.new(34, 0.0)
      end
    end
  end

  context '.economic_costs' do
    let(:economic_cost)  { accounting_tariff.economic_costs(end_date, kwh_data_x48) }

    it 'calculates the expected cost' do
      expect(economic_cost[:differential]).to eq false
      expect(economic_cost[:standing_charges]).to eq({})
      expect(economic_cost[:rates_x48]['flat_rate']).to eq Array.new(48, 0.01 * 0.15)
    end
    context 'with differential rate' do
      let(:tariff_type) { :differential }
      let(:rates) { create_differential_rate(day_rate: 0.30, night_rate: 0.15, standing_charge: nil) }

      it 'calculates the expected cost' do
        expect(economic_cost[:differential]).to eq true
        expect(economic_cost[:standing_charges]).to eq({})
        expect(economic_cost[:rates_x48]['07:00 to 23:30']).to eq Array.new(14, 0.0) + Array.new(34, 0.01 * 0.15)
        expect(economic_cost[:rates_x48]['00:00 to 06:30']).to eq Array.new(14, 0.01 * 0.30) + Array.new(34, 0.0)
      end
    end
  end
end
