class MeterIndicativeStandingCharge
  include Logging
  def initialize(meter, tariff)
    @mpxn = meter.mpxn
    @tariff = tariff
  end

  def daily_standing_charge_£_per_day
    if (defined? @tariff) && !@tariff.nil?
      logger.info "Using indicative standing charge for meter #{@mpxn} of #{@tariff[:rate]}"
      @tariff[:rate]
    else
      3.0
    end
  end
end
