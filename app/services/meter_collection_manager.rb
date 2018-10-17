# Handles merging of raw amr data imported from external sources
# with existing amr data held in Energy Sparks database (postgress, yaml or marshal)
#
# Usage - for loading job
# 1. for one school load all amr datameter_collection from Energy Sparks Database (#existing')
# 2. load all new data associated with school from external sources ('new')
# 3. process data: adjust bad, aggregate, split into storage heaters, solar pv (TBD)
# 4. save back updated data to Energy Sparks database based on arrays of a. deleted b. inserted c. updated data (outside this class)
#
# potentially more than one set of meter readings stored on the Energy Sparks database (original and processed) for same date
#

class MeterCollectionManager
  include Logging

  attr_reader :inserted, :updated, :deleted # list of meter readings following comparison between existing and new readings

  def initialize(existing_meter_collection, new_meter_collection)
    @existing_meter_collection = existing_meter_collection
    @existing_meter_list = id_to_meter_map(existing_meter_collection)

    @new_meter_collection = new_meter_collection
    @new_meter_list = id_to_meter_map(new_meter_collection)
  end

  def compare
    logger.info "Comparing meters for #{@new_meter_collection.name}"
    compare_meters

    @existing_meter_list.keys.each do |id|
      compare_meter_readings(id)
    end
  end

  private

  def id_to_meter_map(meter_collection)
    map = {}
    (meter_collection.heat_meters + meter_collection.electricity_meters).each do |meter|
      map[meter.id] = meter
    end
    map
  end

  def compare_meters
    missing = missing_meters
    unless missing.empty?
      missing.each do |meter_id|
        logger.info "Warning: meter #{id} present in existing data but missing from new feed"
      end
    end

    new_list = new_meters
    unless new_list.empty?
      new_list.each do |meter_id|
        logger.info "Warning: new meter #{id} not in existing feed"
      end
    end
  end

  def missing_meters
    missing_meter_id = []
    @existing_meter_list.each do |id, existing_meter|
      missing_meter_id.push(id) unless @new_meter_list.key?(id)
    end
    missing_meter_id
  end

  def new_meters
    new_meter_id = []
    @new_meter_list.each do |id, new_meter|
      new_meter_id.push(id) unless @existing_meter_list.key?(id)
    end
    new_meter_id
  end

  def compare_meter_readings(id)
    @inserted = []
    @updated = []
    @deleted = []

    logger.info "Comparing meter_readings for #{id}"
    existing_amr_data = @existing_meter_collection.meter?(id).amr_data
    new_amr_data = @new_meter_collection.meter?(id).amr_data

    existing_amr_data.keys.each do |date|
      if new_amr_data.key?(date)
        if existing_amr_data[date] != new_amr_data[date]
          @updated.push(existing_amr_data[date])
          logger.debug "existing: #{existing_amr_data[date]}"
          logger.debug "new:      #{new_amr_data[date]}"
        end
      else
        @deleted.push(new_amr_data[date])
        logger.debug "deleted:  #{new_amr_data[date]}"
      end
    end

    new_amr_data.keys.each do |date|
      unless existing_amr_data.key?(date)
        @inserted.push(new_amr_data[date])
        logger.debug "new:      #{new_amr_data[date]}"
      end
    end

    logger.info "New(inserted) * #{@inserted.length}, Changed(updated} * #{@updated.length}, Deleted * #{@deleted.length}"
  end
end