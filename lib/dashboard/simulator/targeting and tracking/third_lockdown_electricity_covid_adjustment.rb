# between 4 Jan 2021 and 8 Mar 2021 during the thrid UK lockdown
# some schools saw up to a 30% reduction in electricity usage
# this needs to be adjusted for for setting targets for 2021/2022
#
# 1. try to determine whether there has been a signifcant drop, if not do nothing
# 2. if Jan to March 2020 data available use that
# 3. if not then:
#    a. use data from the Autumn as a substitute
#    b. adjust upwards the fit to the 2020/2021 data ex. the 3rd lockdown 
class ThirdLockdownElectricityCovidAdjustment
  def initialize(amr_data, holidays, start_date, end_date)
    @amr_data = amr_data
    @holidays = holidays
    @start_date = start_date
    @end_date = end_date
    @lockdown_start_date = Date.new(2021, 1, 4)
    @lockdown_end_date = Date.new(2021, 3, 7)
  end

  def needs_adjustment?
    return false if start_date > @lockdown_end_date

    fitter = ElectricityAnnualProfileFitter.new(@amr_data, @holidays, @start_date, @end_date)
    fitted_data = fitter.fit

  end
end
