module TestDirectoryConfiguration
  LOG                 = './log'
  CHARTS              = './Reports'
  BENCHMARKFILENAME   = './Results/testtimes/benchmarks.csv'
  RESULTS             = './Results'       
  CHARTCOMPARISONBASE = ENV['ANALYTICSTESTRESULTDIR'] + '/Charts/Base/'
  CHARTCOMPARISONNEW  = ENV['ANALYTICSTESTRESULTDIR'] + '/Charts/New/'
end

class TestDirectory
  include Singleton
  def results_directory; './Results/Benchmark/' end
end
