# temporary class to enhance meter data model prior to this data being
# stored in the database, and ensure PH's YAML meter representation
# which already holds this data stays in sync with postgress
class MeterAdjustments
  extend Logging

  def self.meter_adjustment(meter)
    meter_identifier = meter.mpan_mprn || meter.id
    meter_identifier = meter_identifier.to_s

    case meter_identifier
    when '13685103' # St Marks Orchard Lodge

      meter.meter_correction_rules = min_start_date_rule(Date.new(2015, 1, 1))
      logger.info 'Applying meter correction rules to #{meter.id}:'
      logger.debug meter.meter_correction_rules.inspect
    when '9206222810' # St Johns Primary
      meter.meter_correction_rules = min_start_date_rule(Date.new(2017, 2, 21))
      logger.info 'Applying meter correction rules to #{meter.id}:'
      logger.debug meter.meter_correction_rules.inspect
    when '13678903' # Paulton Junior Gas
      meter.meter_correction_rules = min_start_date_rule(Date.new(2014, 9, 30))
      logger.info 'Applying meter correction rules to #{meter.id}:'
      logger.debug meter.meter_correction_rules.inspect
    when '13678903', '50974602', '50974703', '50974804', '75665705' # Roundhill
      meter.meter_correction_rules = rescale_amr_data_rule(Date.new(2009, 1, 1), Date.new(2012, 1, 1), 1/31.1)
      logger.info 'Applying meter correction rules to #{meter.id}:'
      logger.debug meter.meter_correction_rules.inspect
    end
  end

  def self.min_start_date_rule(date)
    correction = {
      readings_start_date: date,
      auto_insert_missing_readings: :weekends
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
