require 'spec_helper'

describe GenericTariffManager, type: :service do

  let(:end_date)    { Date.today }
  let(:start_date)  { Date.today - 30 }

  let(:rates)       { create_flat_rate }

  let(:accounting_tariff) { create_accounting_tariff_generic(start_date: start_date, end_date: end_date, rates: rates, tariff_holder: :site_settings) }

  let(:meter_attributes) {
    {:accounting_tariff_generic=> [accounting_tariff]}
  }

  let(:kwh_data_x48)       { Array.new(48, 0.01) }
  let(:amr_end_date)       { end_date }

  let(:meter) { build(:meter,
      type: :electricity,
      meter_attributes: meter_attributes,
      amr_data: build(:amr_data, :with_days, day_count: 31, end_date: amr_end_date, kwh_data_x48: kwh_data_x48)
    )
  }

  let(:service)    { GenericTariffManager.new(meter) }

  #TEMPORARY, need to add code to switch in different implementation
  #Stub the creation of the tariff manager called via the Meter constructor
  before(:each) do
    allow_any_instance_of(Dashboard::Meter).to receive(:create_tariff_manager) do
      nil
    end
  end

  context '#initialize' do
    context 'smart meter tariffs' do
      #amr data will be 1st - 31st Jan
      let(:amr_end_date)       { Date.new(2023,1,31) }

      #set tariff to start after the meter data
      let(:start_date)         { Date.new(2023, 1, 15) }
      let(:end_date)           { Date.new(2050, 1, 1) }

      let(:accounting_tariff)  { create_accounting_tariff_generic(start_date: start_date, end_date: end_date, source: :dcc, rates: rates, tariff_holder: :meter) }

      let(:tariff) { service.meter_tariffs.first }
      it 'backdates the tariffs to the amr start date' do
        expect(tariff.tariff[:start_date]).to eq amr_end_date - 30
      end
    end
  end

  context '.accounting_tariff_for_date' do
    let(:search_date)     { end_date }
    let(:found_tariff)    { service.accounting_tariff_for_date(search_date) }
    it 'supports old method name' do
      expect(found_tariff).to_not be_nil
    end
  end

  context '.find_tariff_for_date' do
    let(:search_date)     { end_date }
    let(:found_tariff)    { service.find_tariff_for_date(search_date) }

    context 'with no tariff' do
      let(:meter_attributes)  { {} }
      it 'returns nil' do
        expect(found_tariff).to be_nil
      end
    end

    context 'with date outside range' do
      let(:search_date)       { Date.today - 365 }
      it 'returns nil' do
        expect(found_tariff).to be_nil
      end
    end

    context 'with only system settings tariff' do
      it 'returns the tariff' do
        expect(found_tariff).to_not be_nil
        expect(found_tariff.tariff).to eq accounting_tariff
      end
    end

    context 'with a school group tariff' do
      let(:tariff_holder) { :school_group }
      it 'returns the tariff' do
        expect(found_tariff).to_not be_nil
        expect(found_tariff.tariff).to eq accounting_tariff
      end
    end
    context 'with a school tariff' do
      let(:tariff_holder) { :school }
      it 'returns the tariff' do
        expect(found_tariff).to_not be_nil
        expect(found_tariff.tariff).to eq accounting_tariff
      end
    end
    context 'with a meter tariff' do
      let(:tariff_holder) { :meter }
      it 'returns the tariff' do
        expect(found_tariff).to_not be_nil
        expect(found_tariff.tariff).to eq accounting_tariff
      end
    end
    context 'with a full hierarchy of tariffs' do
      let(:site)            { create_accounting_tariff_generic(tariff_holder: :site_settings) }
      let(:school_group)    { create_accounting_tariff_generic(tariff_holder: :school_group) }
      let(:school)          { create_accounting_tariff_generic(tariff_holder: :school) }
      let(:meter_tariff)    { create_accounting_tariff_generic(tariff_holder: :meter) }

      let(:meter_attributes) {
        {:accounting_tariff_generic=> [site, school_group, school, meter_tariff]}
      }

      it 'returns the applicable meter tariff first' do
        expect(found_tariff).to_not be_nil
        expect(found_tariff.tariff).to eq meter_tariff
      end
    end

    context 'with a hierarchy of overlapping tariffs' do
      let(:search_date)  { Date.new(2023, 1, 15) }

      let(:school_group) { create_accounting_tariff_generic(tariff_holder: :school_group,
        start_date: Date.new(2022, 1,1), end_date: Date.new(2024, 1, 1)) }

      let(:school)       { create_accounting_tariff_generic(tariff_holder: :school,
        start_date: Date.new(2023, 1, 1), end_date: Date.new(2023, 4, 1)) }

      let(:meter_tariff) { create_accounting_tariff_generic(tariff_holder: :meter,
        start_date: Date.new(2022, 6, 1), end_date: Date.new(2023, 1, 5)) }

      let(:meter_attributes) {
        {:accounting_tariff_generic=> [school_group, school, meter_tariff]}
      }

      it 'falls back to the school tariff when the meter tariff doesnt apply' do
        expect(found_tariff).to_not be_nil
        expect(found_tariff.tariff).to eq school
      end
    end

    context 'with overlapping tariffs at the same level' do
      let(:older) { create_accounting_tariff_generic(created_at: DateTime.now - 30, tariff_holder: :school) }
      let(:newer) { create_accounting_tariff_generic(tariff_holder: :school) }

      let(:meter_attributes) {
        {:accounting_tariff_generic=> [older, newer]}
      }

      it 'returns the most recently created' do
        expect(found_tariff.tariff).to eq newer
      end

      context 'and one has a missing timestamp' do
        let(:older) { create_accounting_tariff_generic(created_at: nil, tariff_holder: :school) }
        it 'returns the most recently created' do
          expect(found_tariff.tariff).to eq newer
        end
      end
    end
  end

  context '.economic_cost' do
    let(:rates)           { create_flat_rate(rate: 0.15, standing_charge: nil) }
    let(:economic_cost)   { service.economic_cost(amr_end_date, kwh_data_x48) }

    it 'calculates the expected cost' do
      expect(economic_cost.differential_tariff?).to eq false
      expect(economic_cost.standing_charges).to eq({})
      expect(economic_cost.all_costs_x48['flat_rate']).to eq Array.new(48, 0.01 * 0.15)
    end

  end

  context '.accounting_cost' do
    let(:rates)           { create_flat_rate(rate: 0.15, standing_charge: nil) }

    let(:accounting_cost) { service.accounting_cost(amr_end_date, kwh_data_x48)}

    it 'calculates the expected cost' do
      expect(accounting_cost.differential_tariff?).to eq false
      expect(accounting_cost.standing_charges).to eq({})
      expect(accounting_cost.all_costs_x48['flat_rate']).to eq Array.new(48, 0.01 * 0.15)
    end

    context 'with a standing charge when available' do
      let(:rates)           { create_flat_rate(rate: 0.15, standing_charge: 1.0) }
      it 'includes the charge' do
        expect(accounting_cost.standing_charges).to eq({standing_charge: 1.0})
      end
    end
  end

  context '.any_differential_tariff?' do
    context 'with flat rate' do
      it 'returns false' do
        expect(service.any_differential_tariff?(start_date, end_date)).to be false
      end
    end
    context 'with differential' do
      let(:rates) { create_differential_rate }
      it 'returns true' do
        expect(service.any_differential_tariff?(start_date, end_date)).to be true
      end
    end

    context 'when an inherited tariff is differential' do
      let(:school)          { create_accounting_tariff_generic(tariff_holder: :school, start_date: start_date, end_date: end_date, rates: create_differential_rate) }
      let(:meter_tariff)    { create_accounting_tariff_generic(tariff_holder: :meter, start_date: start_date + 15) }
      let(:meter_attributes) {
        {:accounting_tariff_generic=> [school, meter_tariff]}
      }
      it 'returns true' do
        expect(service.any_differential_tariff?(start_date, end_date)).to be true
      end
    end
  end

  context '.last_tariff_change_date' do
    let(:t1_start_date)  { Date.new(2022,1,1) }
    let(:t1_end_date)    { Date.new(2022,12,31) }

    let(:tariff_1) { create_accounting_tariff_generic(start_date: t1_start_date, end_date: t1_end_date) }

    let(:t2_start_date)  { Date.new(2023,1,1) }
    let(:t2_end_date)    { Date.new(2023,12,31) }

    let(:tariff_2) { create_accounting_tariff_generic(start_date: t2_start_date, end_date: t2_end_date) }

    let(:meter_attributes) {
      {:accounting_tariff_generic=> [tariff_1, tariff_2]}
    }

    let(:search_start_date)     { Date.new(2023, 4, 1)  }
    let(:search_end_date)       { Date.new(2023, 4, 30) }

    let(:change_date)     { service.last_tariff_change_date(search_start_date, search_end_date) }

    context 'searching within range of latest tariff' do
      it 'there was no change' do
        expect(change_date).to eq nil
      end
    end

    context 'searching beyond range of latest tariff' do
      let(:search_start_date)     { Date.new(2024, 1, 1)  }
      let(:search_end_date)       { Date.new(2024, 12, 31) }

      it 'there was no change' do
        expect(change_date).to eq nil
      end
    end

    context 'searching with range overlapping latest tariff' do
      let(:search_start_date)     { Date.new(2023, 10, 1)  }
      let(:search_end_date)       { Date.new(2024, 1, 31) }

      it 'returns no change' do
        expect(change_date).to eq nil
      end
    end

    context 'searching with range overlapping change of tariffs' do
      let(:search_start_date)     { Date.new(2022, 10, 1)  }
      let(:search_end_date)       { Date.new(2023, 1, 31) }

      it 'returns latest tariff' do
        expect(change_date).to eq t2_start_date
      end
    end

    context 'searching within range of previous tariff' do
      let(:search_start_date)     { Date.new(2022, 4, 1)  }
      let(:search_end_date)       { Date.new(2022, 4, 30) }

      it 'find previous tariff date' do
        expect(change_date).to eq nil
      end
    end

    context 'searching outside range of first tariff' do
      let(:search_start_date)     { Date.new(2021, 1, 1) }
      let(:search_end_date)       { Date.new(2021, 1, 31) }

      it 'returns nil' do
        expect(change_date).to eq nil
      end
    end

    context 'across both tariffs' do
      let(:search_start_date)     { Date.new(2021, 1, 1) }
      let(:search_end_date)       { Date.new(2024, 1, 1) }

      it 'returns latest tariff' do
        expect(change_date).to eq t2_start_date
      end
    end

    context 'within open ended tariff' do
      let(:t1_start_date)         { nil }
      let(:t2_end_date)           { nil }
      let(:search_start_date)     { Date.new(2021, 1, 1) }
      let(:search_end_date)       { Date.new(2024, 1, 1) }

      it 'returns latest tariff' do
        expect(change_date).to eq t2_start_date
      end
    end

    context 'searching before MIN_DEFAULT_START_DATE' do
      let(:t1_start_date)         { nil }
      let(:t2_end_date)           { nil }
      let(:search_start_date)     { Date.new(1999, 1, 1) }
      let(:search_end_date)       { Date.new(2021, 1, 1) }

      it 'returns nil' do
        expect(change_date).to eq nil
      end
    end

  end

  context '.tariff_change_dates_in_period' do
    let(:t1_start_date)  { Date.new(2022,1,1) }
    let(:t1_end_date)    { Date.new(2022,12,31) }

    let(:tariff_1) { create_accounting_tariff_generic(start_date: t1_start_date, end_date: t1_end_date) }

    let(:t2_start_date)  { Date.new(2023,1,1) }
    let(:t2_end_date)    { Date.new(2023,12,31) }

    let(:tariff_2) { create_accounting_tariff_generic(start_date: t2_start_date, end_date: t2_end_date) }

    let(:meter_attributes) {
      {:accounting_tariff_generic=> [tariff_1, tariff_2]}
    }

    let(:search_start_date)     { Date.new(2023, 4, 1)  }
    let(:search_end_date)       { Date.new(2023, 4, 30) }

    let(:change_dates)     { service.tariff_change_dates_in_period(search_start_date, search_end_date) }

    context 'searching within range of latest tariff' do
      it 'there was no change' do
        expect(change_dates).to eq []
      end
    end

    context 'searching beyond range of latest tariff' do
      let(:search_start_date)     { Date.new(2024, 1, 1)  }
      let(:search_end_date)       { Date.new(2024, 12, 31) }

      it 'there was no change' do
        expect(change_dates).to eq []
      end
    end

    context 'searching with range overlapping latest tariff' do
      let(:search_start_date)     { Date.new(2023, 10, 1)  }
      let(:search_end_date)       { Date.new(2024, 1, 31) }

      it 'returns no change' do
        expect(change_dates).to eq []
      end
    end

    context 'searching with range overlapping a change of tariffs' do
      let(:search_start_date)     { Date.new(2022, 12, 1)  }
      let(:search_end_date)       { Date.new(2023, 1, 31) }

      it 'returns start of latest tariff' do
        expect(change_dates).to eq [t2_start_date]
      end
    end

    context 'searching within range of previous tariff' do
      let(:search_start_date)     { Date.new(2022, 4, 1)  }
      let(:search_end_date)       { Date.new(2022, 4, 30) }

      it 'find previous tariff date' do
        expect(change_dates).to eq []
      end
    end

    context 'searching outside range of first tariff' do
      let(:search_start_date)     { Date.new(2021, 1, 1) }
      let(:search_end_date)       { Date.new(2021, 1, 31) }

      it 'returns nil' do
        expect(change_dates).to eq []
      end
    end

    context 'across both tariffs' do
      let(:search_start_date)     { Date.new(2021, 1, 1) }
      let(:search_end_date)       { Date.new(2024, 1, 1) }

      it 'returns latest tariffs' do
        expect(change_dates).to eq [t2_start_date]
      end
    end

    context 'within open ended tariff' do
      let(:t1_start_date)         { nil }
      let(:t2_end_date)           { nil }
      let(:search_start_date)     { Date.new(2021, 1, 1) }
      let(:search_end_date)       { Date.new(2024, 1, 1) }

      it 'returns latest tariff' do
        expect(change_dates).to eq [t2_start_date]
      end
    end

    context 'searching before MIN_DEFAULT_START_DATE' do
      let(:t1_start_date)         { nil }
      let(:t2_end_date)           { nil }
      let(:search_start_date)     { Date.new(1999, 1, 1) }
      let(:search_end_date)       { Date.new(2021, 1, 1) }

      it 'returns nil' do
        expect(change_dates).to eq []
      end
    end

  end

  context '.tariffs_differ_within_date_range?' do
    let(:t1_start_date)  { Date.new(2022,1,1) }
    let(:t1_end_date)    { Date.new(2022,12,31) }

    let(:tariff_1) { create_accounting_tariff_generic(start_date: t1_start_date, end_date: t1_end_date) }

    let(:t2_start_date)  { Date.new(2023,1,1) }
    let(:t2_end_date)    { Date.new(2023,12,31) }

    let(:tariff_2) { create_accounting_tariff_generic(start_date: t2_start_date, end_date: t2_end_date) }

    let(:meter_attributes) {
      {:accounting_tariff_generic=> [tariff_1, tariff_2]}
    }

    let(:search_start_date)     { Date.new(2023, 4, 1)  }
    let(:search_end_date)       { Date.new(2023, 4, 30) }

    let(:changed) { service.tariffs_differ_within_date_range?(search_start_date, search_end_date) }

    context 'when there has been no change' do
      it 'returns false' do
        expect(changed).to eq false
      end
    end

    context 'when there has been a change' do
      let(:search_start_date)     { Date.new(2022, 12, 1)  }
      let(:search_end_date)       { Date.new(2023, 2, 1) }

      it 'returns true' do
        expect(changed).to eq true
      end
    end

  end

  context '.tariffs_change_between_periods?' do
    let(:t1_start_date)  { Date.new(2022,1,1) }
    let(:t1_end_date)    { Date.new(2022,12,31) }

    let(:tariff_1) { create_accounting_tariff_generic(start_date: t1_start_date, end_date: t1_end_date) }

    let(:t2_start_date)  { Date.new(2023,1,1) }
    let(:t2_end_date)    { Date.new(2023,12,31) }

    let(:tariff_2) { create_accounting_tariff_generic(start_date: t2_start_date, end_date: t2_end_date) }

    let(:meter_attributes) {
      {:accounting_tariff_generic=> [tariff_1, tariff_2]}
    }

    let(:first_period)    { Date.new(2023, 2, 1)..Date.new(2023, 3, 1)}
    let(:second_period)   { Date.new(2023, 3, 1)..Date.new(2023, 4, 1)}
    let(:changed) { service.tariffs_change_between_periods?(first_period, second_period) }

    context 'with no change' do
      it 'returns false' do
        expect(changed).to eq false
      end
    end

    context 'with a change' do
      let(:first_period)    { Date.new(2022, 2, 1)..Date.new(2022, 3, 1)}
      it 'returns false' do
        expect(changed).to eq true
      end
    end

  end

  context '.meter_tariffs_differ_within_date_range?' do
    let(:t1_start_date)  { Date.new(2022,1,1) }
    let(:t1_end_date)    { Date.new(2022,12,31) }

    let(:tariff_1) { create_accounting_tariff_generic(start_date: t1_start_date, end_date: t1_end_date) }

    let(:t2_start_date)  { Date.new(2023,1,1) }
    let(:t2_end_date)    { Date.new(2023,12,31) }

    let(:tariff_2) { create_accounting_tariff_generic(start_date: t2_start_date, end_date: t2_end_date) }

    let(:meter_attributes) {
      {:accounting_tariff_generic=> [tariff_1, tariff_2]}
    }

    let(:search_start_date)     { Date.new(2023, 4, 1)  }
    let(:search_end_date)       { Date.new(2023, 4, 30) }

    let(:changed) { service.meter_tariffs_differ_within_date_range?(search_start_date, search_end_date) }

    before(:each) do
      allow_any_instance_of(Dashboard::Meter).to receive(:meter_tariffs) do
        service
      end
    end

    context 'when there has been no change' do
      it 'returns false' do
        expect(changed).to eq false
      end
    end

    context 'when there has been a change' do
      let(:search_start_date)     { Date.new(2022, 12, 1)  }
      let(:search_end_date)       { Date.new(2023, 2, 1) }

      it 'returns true' do
        expect(changed).to eq true
      end
    end
  end

  context '.meter_tariffs_changes_between_periods?' do
    let(:t1_start_date)  { Date.new(2022,1,1) }
    let(:t1_end_date)    { Date.new(2022,12,31) }

    let(:tariff_1) { create_accounting_tariff_generic(start_date: t1_start_date, end_date: t1_end_date) }

    let(:t2_start_date)  { Date.new(2023,1,1) }
    let(:t2_end_date)    { Date.new(2023,12,31) }

    let(:tariff_2) { create_accounting_tariff_generic(start_date: t2_start_date, end_date: t2_end_date) }

    let(:meter_attributes) {
      {:accounting_tariff_generic=> [tariff_1, tariff_2]}
    }

    let(:first_period)    { Date.new(2023, 2, 1)..Date.new(2023, 3, 1)}
    let(:second_period)   { Date.new(2023, 3, 1)..Date.new(2023, 4, 1)}
    let(:changed) { service.meter_tariffs_changes_between_periods?(first_period, second_period) }

    before(:each) do
      allow_any_instance_of(Dashboard::Meter).to receive(:meter_tariffs) do
        service
      end
    end

    context 'with no change' do
      it 'returns false' do
        expect(changed).to eq false
      end
    end

    context 'with a change' do
      let(:first_period)    { Date.new(2022, 2, 1)..Date.new(2022, 3, 1)}
      it 'returns false' do
        expect(changed).to eq true
      end
    end
  end
end