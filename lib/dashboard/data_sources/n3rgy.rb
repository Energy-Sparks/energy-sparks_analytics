module MeterReadingsFeeds

  # To access the data in the JSON interface you need to traverse a tree:
  #
  # MPAN => electricity => consumption => element = 1 => readings = consumption
  #      => electricity => consumption => element = 1 => readings = tariff
  #      => electricity => production  =>  - would assume this works as above but sandbox example has no entries?
  #      => gas         => consumption => element = 1 => readings = consumption
  #      => gas         => consumption => element = 1 => readings = tariff
  #
  # entries always seems to be 1 in the sandbox examples, more than 1 entry appears to be a Twin Entry meter
  # this combining of the gas MPRN under the electricity meter MPAN is typical of a domestic
  # meter setup; the battery power gas meter conmmunicated wirelessly to the comms hub installed
  # on the mains powered electricity meter which then uploads both sets of data to the DCC
  #
  # however in the non-domestic market it is more likely that the gas meter might not share a
  # comms hub with the electricity meter and be accessible directly; in many schools the gas
  # meter is a long way from the electricity meter
  #
  # In Energy Sparks, we work with a flatter representation:
  #
  #   :electricity          => kwh, £
  #   :exported_electricity => kwh
  #   :gas                  => kwh, £
  #
  # its also no clear despite asking the Q to multiple parties where deemed export meters
  # separate MPANs fit into the DCC versus non-deemed MPANless export meters?
  #
  # usage:
  #           n3rgy.new.all_data(mpxn)
  #
  # returns:
  #           {
  #             electricity: {
  #               kwh: {
  #                 readings: { date => kwhx48 }
  #                 missing_readings: [ DateTime ]
  #               },
  #               cost: {
  #                 kwh_tariffs:  date => kwhx48,
  #                 standing_charges: { DateRange => £/day }
  #                 missing_readings: [ DateTime ]
  #               }
  #             },
  #             gas: { as above },
  #             exported_electricity: { as above, but probably not tariffs, no examples to date so ?????? }
  #           }
  #
  class N3rgy
    include Logging

    attr_reader :raw

    # if production = false accesses the sandbox environment, logging e.g. { puts: true, ap: { limit: 5 } }
    def initialize(api_key: ENV['N3RGY_APP_KEY'], production: false, debugging: nil)
      @api_key = api_key
      @production = production
      @debugging = debugging
      @raw = N3rgyRaw.new(api_key, production, debugging)
    end

    def grant_trusted_consent(mpxn, file_link)
      raw.grant_trusted_consent(mpxn, file_link)
    end

    def withdraw_trusted_consent(mpxn)
      raw.withdraw_trusted_consent(mpxn)
    end

    def session_id(mpxn)
      raw.session_id(mpxn)
    end

    def mpxns
      raw.mpxns
    end

    def inventory
      raw.inventory
    end

    def mpxn_status(mpxn)
      raw.mpxn_status(mpxn)
    end

    def fuel_types(mpxn)
      fuels = raw.fuel_types(mpxn)
      fuels.push(:exported_electricity) if fuels.include?(:electricity) && has_data?(mpxn, :exported_electricity)
      fuels
    end

    def has_data?(mpxn, fuel_type)
      el = elements(mpxn, fuel_type)
      !el.nil? && elements(mpxn, fuel_type).length == 1
    end

    def check_reading_types(mpxn, fuel_type)
      raw.check_reading_types(mpxn, fuel_type(fuel_type))
    end

    def start_date(mpxn, fuel_type)
      download_start_end_dates(mpxn, fuel_type)[:start_date]
    end

    def end_date(mpxn, fuel_type)
      download_start_end_dates(mpxn, fuel_type)[:end_date]
    end

    def units(mpxn, fuel_type)
      el = element(mpxn, fuel_type)
      raw.units(mpxn, fuel_type, el, data_type(fuel_type))
    end

    ####################################################################

    def readings(mpxn, fuel_type, start_date, end_date)
      kwh = kwhs(mpxn, fuel_type, start_date, end_date)
      { fuel_type =>
        {
          mpan_mprn:        mpxn,
          readings:         convert_date_to_x48_to_one_day_readings(kwh[:readings], mpxn, start_date, end_date),
          missing_readings: kwh[:missing_readings]
        }
      }
    end

    def convert_date_to_x48_to_one_day_readings(raw_meter_readings, mpan_mprn, start_date, end_date)
      meter_readings = {}
      (start_date..end_date).each do |date|
        if raw_meter_readings.key?(date)
          meter_readings[date] = OneDayAMRReading.new(mpan_mprn, date, 'ORIG', nil, DateTime.now, raw_meter_readings[date])
        else
          meter_readings[date] = OneDayAMRReading.new(mpan_mprn, date, 'ORIG', nil, DateTime.now, Array.new(48, 0.0))
          message = "Warning: missing meter readings for #{mpan_mprn} on #{date}"
          logger.warn message
        end
      end
      meter_readings
    end

    ####################################################################

    def all_data(mpxn)
      data_by_fuel_type = {}
      fuel_types(mpxn).each do |fuel_type|
        raw.log("Downloading data for #{fuel_type}")
        if has_data?(mpxn, fuel_type)
          kwh  = kwhs(mpxn, fuel_type)
          cost = tariffs(mpxn, fuel_type)

          raw.log("Downloaded #{kwh[:readings].length} days of data for #{mpxn} of fuel type #{fuel_type}")

          data_by_fuel_type[fuel_type] = {kwh:  kwh, cost: cost}
        else
          raw.log("no data for #{mpxn} #{fuel_type}")
          data_by_fuel_type[fuel_type] = nil
        end
      end
      data_by_fuel_type
    end

    def kwhs(mpxn, fuel_type, start_date = start_date(mpxn, fuel_type), end_date = end_date(mpxn, fuel_type))
      el = element(mpxn, fuel_type)
      processed_meter_readings_kwh(mpxn, fuel_type, el, start_date, end_date)
    end

    def tariffs(mpxn, fuel_type, start_date = start_date(mpxn, fuel_type), end_date = end_date(mpxn, fuel_type))
      el = element(mpxn, fuel_type)
      processed_meter_readings_£(mpxn, fuel_type, el, start_date, end_date)
    end

    private

    def data_type(fuel_type)
      fuel_type == :exported_electricity ? :production : :consumption
    end

    # translate :exported_electricity into :electricity
    def fuel_type(fuel_type)
      fuel_type == :gas ? :gas : :electricity
    end

    def download_start_end_dates(mpxn, fuel_type)
      el = element(mpxn, fuel_type)
      raw.start_end_date_by_fuel(mpxn, fuel_type, el, data_type(fuel_type))
    end

    # no data case protected by calling has_data?(mpxn, fuel_type)
    def element(mpxn, fuel_type)
      elements(mpxn, fuel_type)[0]
    end

    def elements(mpxn, fuel_type)
      raw.meter_elements(mpxn, fuel_type(fuel_type), data_type(fuel_type))
    end

    def processed_meter_readings_kwh(mpxn, fuel_type, element, start_date, end_date)
      raw_kwhs = raw.raw_meter_readings_kwh(mpxn, fuel_type, element, start_date, end_date)
      dt_to_kwh = raw.convert_readings_dt_to_kwh(raw_kwhs, mpxn, fuel_type, element, data_type(fuel_type))
      convert_dt_to_v_to_date_to_v_x48(start_date, end_date, dt_to_kwh)
    end

    def processed_meter_readings_£(mpxn, fuel_type, element, start_date, end_date)
      raw_£ = raw.raw_tariffs_£(mpxn, fuel_type, element, start_date, end_date)

      standing_charges = convert_standing_charges_to_range(raw_£[:standing_charges], fuel_type)

      dt_to_£ = raw.convert_readings_dt_to_£(raw_£[:prices], mpxn, fuel_type)

      tariffs = convert_dt_to_v_to_date_to_v_x48(start_date, end_date, dt_to_£)

      {
        kwh_tariffs:      tariffs[:readings],
        standing_charges: standing_charges,
        missing_readings: tariffs[:missing_readings],
      }
    end

    # convert n3rgy standing charge representation to compact
    # hash representation, as per Energy Sparks accounting tariff attributes
    def convert_standing_charges_to_range(standing_charges_date_str, fuel_type)
      sc_sd_to_v = standing_charges_date_str.map.with_index do |current_sc, index|
        [
          to_date2(current_sc['startDate']),
          current_sc['value'] / raw.standing_charge_£_units(fuel_type)
        ]
      end

      standing_charges = {}
      start_date = sc_sd_to_v.first[0]
      value      = sc_sd_to_v.first[1]
      (0...(sc_sd_to_v.length-1)).each do |index|
        if sc_sd_to_v[index][1] != sc_sd_to_v[index+1][1]
          standing_charges[start_date..(sc_sd_to_v[index + 1][0] - 1)] = sc_sd_to_v[index][1]
          start_date = sc_sd_to_v[index+1][0]
        end
      end
      standing_charges[start_date..Date.new(2050, 1, 1)] = sc_sd_to_v.last[1]

      standing_charges
    end

    def to_date2(date_str)
      Date.strptime(date_str, '%Y-%m-%d')
    end

    def convert_dt_to_v_to_date_to_v_x48(start_date, end_date, dt_to_kwh)
      missing_readings = []
      readings = Hash.new { |h, k| h[k] = Array.new(48, 0.0) }

      # iterate through data at fixed time intervals
      # so missing date times can be spotted
      (start_date..end_date).each do |date|
        (0..23).each do |hour|
          [0, 30].each_with_index do |mins30, hh_index|
            dt = datetime_to_30_minutes(date, hour, mins30)
            # dt = adjust_to_bst(dt) if adjust_to_bst # raw data in UTC, convert to local time
            if dt_to_kwh.key?(dt)
              readings[date][hour * 2 + hh_index] = dt_to_kwh[dt]
            else
              missing_readings.push(dt)
            end
          end
        end
      end
      {
        readings:         readings,
        missing_readings: missing_readings
      }
    end

    def datetime_to_30_minutes(date, hour, mins)
      DateTime.new(date.year, date.month, date.day, hour, mins, 0)
    end
  end
end
