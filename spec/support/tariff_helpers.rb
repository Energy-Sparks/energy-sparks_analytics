module EnergySparksAnalyticsDataHelpers

  def create_flat_rate(rate: 0.15, standing_charge: nil)
    rates = {
      flat_rate: {
        per: :kwh,
        rate: rate
      }
    }
    if standing_charge
      rates[:standing_charge] = {
        per: :day,
        rate: standing_charge
      }
    end
    rates
  end

  def create_differential_rate(day_rate: 0.30, night_rate: 0.15, standing_charge: nil)
    rates = {
      rate0: {
        from: TimeOfDay.new(7,0),
        to: TimeOfDay.new(0,0),
        per: :kwh,
        rate: night_rate
      },
      rate1: {
        from: TimeOfDay.new(0,0),
        to: TimeOfDay.new(6,30),
        per: :kwh,
        rate: day_rate
      }
    }
    if standing_charge
      rates[:standing_charge] = {
        per: :day,
        rate: standing_charge
      }
    end
    rates
  end

  def create_accounting_tariff_generic(start_date: Date.yesterday, end_date: Date.today, name: "Tariff #{rand}", source: :manually_entered, tariff_holder: :site_settings, type: :flat, vat: "0%", created_at: DateTime.now, rates: create_flat_rate)
    {
      start_date: start_date,
      end_date: end_date,
      name: name,
      source: source,
      type: type,
      tariff_holder: tariff_holder,
      created_at: created_at,
      vat: vat,
      rates: rates
    }
  end

end
