# override main analytics library functions specifically
# for where test only benchmarking and calibration
# code is being used, a dangerous approach but it
# has been required by the front end developers, it runs
# the risk of the analytics testing  different code
# than used in the front end; so great care needs to
# be taken with its use
class AlertHeatingOnOff
  private def cached_dark_sky_for_testing
    unless defined?(@@dark_sky_cache)
      test_dir = TestDirectory.instance.test_directory_name('Alerts')
      filename = File.join(test_dir, 'dark_sky_forecast_cache.yaml')
      if File.exist?(filename)
        @@dark_sky_cache, @@cached_forecast_date_time = YAML::load_file(filename)
      else
        @@dark_sky_cache = dark_sky_forecast unless defined?(@@dark_sky_cache)
        @@cached_forecast_date_time = @forecast_date_time
        File.open(filename, 'w') { |f| f.write(YAML.dump([@@dark_sky_cache, @@cached_forecast_date_time])) }
      end
    end
    @forecast_date_time = @@cached_forecast_date_time
    @@dark_sky_cache
  end
end
