# temporary class to enhance meter data model prior to this data being
# stored in the database, and ensure PH's YAML meter representation
# which already holds this data stays in sync with postgress
class MeterAdjustments
  extend Logging

  def self.meter_adjustment(meter)
    case meter.mpan_mprn
    when 13685103 # St Marks Orchard Lodge
      # meter.add_correction_rule(min_start_date_rule(Date.new(2015, 1, 1)))
      # logger.info "Applying meter correction rules to #{meter.id}:"
    when 9206222810 # St Johns Primary
      # meter.add_correction_rule(min_start_date_rule(Date.new(2017, 2, 21)))
      # logger.info "Applying meter correction rules to #{meter.id}:"
    when 2200012581120 # Twerton Infant Missing data from 26/6/2018 to 3/8/2019
      # meter.add_correction_rule(set_all_missing_data_to_zero(DateTime.new(2018, 6, 17), DateTime.new(2018, 8, 30)))
      # logger.info "Applying meter correction rules to #{meter.id}:"
    when 13678903 # Paulton Junior Gas
      # meter.add_correction_rule(min_start_date_rule(Date.new(2014, 9, 30)))
      # logger.info "Applying meter correction rules to #{meter.id}:"
    # when 75665806 #  '50974602', '50974703', '50974804', '75665705' # Roundhill
      # meter.add_correction_rule(rescale_amr_data_rule(Date.new(2009, 1, 1), Date.new(2009, 1, 1), 1/31.1))
      # logger.info "Applying meter correction rules to #{meter.id}:"
    end

    case meter.mpan_mprn
    when 75665806, 50974602, 50974703, 50974804, 75665705 # Roundhill
      meter.add_correction_rule(set_all_missing_data_to_zero(Date.new(2016, 1, 1), Date.new(2018, 8, 12)))
      logger.info "Applying meter missing data to #{meter.id}:"
    end
    logger.debug meter.meter_correction_rules.inspect
  end

  def self.min_start_date_rule(date)
    correction = {
      readings_start_date: date,
      auto_insert_missing_readings: {
        type:       :weekends
      }
    }
    correction
  end

  def self.deprecated_rule
    { deprecated: true }
  end

  def self.set_all_missing_data_to_zero(start_date = nil, end_date = nil)
    correction = {
      auto_insert_missing_readings: {
        type:       :date_range,
        start_date: start_date,
        end_date:   end_date
      }
    }
    correction
  end

  def self.set_bad_data_to_zero(start_date = nil, end_date = nil)
    correction = {
      set_bad_data_to_zero: {
        start_date: start_date,
        end_date:   end_date
      }
    }
    correction
  end

  def self.rescale_amr_data_rule(start_date, end_date, scale)
    correction = {
      rescale_amr_data: {
        start_date: start_date,
        end_date: end_date,
        scale:  scale
      }
    }
    correction
  end
end
