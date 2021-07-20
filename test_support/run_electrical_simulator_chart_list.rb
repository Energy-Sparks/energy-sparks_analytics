class RunElectricalSimulatorChartList < RunDashboardChartList
  private def excel_variation; '- electrical simulator' end
  private def name; 'Running electrical simulation advice for' end
  private def short_name; 'electrical simulation' end
  private def dashboard_configs; %i[simulator simulator_detail] end
  def meters; [@school.aggregated_electricity_meters] end

  def precalculation
    simulator = ElectricitySimulator.new(@school)

    bm = Benchmark.measure {
      simulator.simulate(simulator.default_simulator_parameters)
    }
    puts "Simulator took: #{bm.to_s}"
  end

  def run_single_dashboard_page(single_page_config, mpan_mprn)
    puts "#{name} #{mpan_mprn}"
    single_page_config[:charts].each do |chart_name|
      run_chart(mpan_mprn.to_s, chart_name)
    end
  end
end
