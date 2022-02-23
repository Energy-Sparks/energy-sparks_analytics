# override main analytics library functions specifically
# for where test only benchmarking and calibration
# code is being used, a dangerous approach but it
# has been required by the front end developers, it runs
# the risk of the analytics testing  different code
# than used in the front end; so great care needs to
# be taken with its use
class WeatherForecastCache
  private

  def add_cache(forecast_data, asof_date)
    cache(asof_date).push(forecast_data)
    # a little inefficient as will save ~30/multiple times on 1st batch run
    file_writer(asof_date).save(cache(asof_date))
  end

  def filename_stub(asof_date)
    File.join(TestDirectory.instance.test_directory_name('Alerts'), "weatherforecastcache #{asof_date}")
  end

  def file_writer(asof_date)
    FileWriter.new(filename_stub(asof_date))
  end

  def cache(asof_date)
    @cache ||= Hash.new { |hash, key| hash[key] = [] }
    
    @cache[asof_date] = file_writer(asof_date).load if @cache[asof_date].nil? && file_writer(asof_date).exists?

    @cache[asof_date]
  end
end
