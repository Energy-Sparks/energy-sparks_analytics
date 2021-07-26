class RunElectricalSimulatorChartList < RunDashboardChartList
  private def excel_variation; '- electrical simulator' end
  private def name; 'Running electrical simulation advice for' end
  private def short_name; 'electrical simulation' end
  private def dashboard_configs; %i[simulator simulator_detail] end
  def meters; [@school.aggregated_electricity_meters] end

  def precalculation(control)
    simulator = ElectricitySimulator.new(@school)
    puts "Choice of config files:"
    ap config_files

    save_yaml_parameters(simulator.default_simulator_parameters, 'default')

    manual_config_files = config_files.select { |filename| filename.match("test") }

    ap manual_config_files

    if !manual_config_files.empty?
      bm = Benchmark.measure {
        parameters = load_yaml(manual_config_files[0])
        simulator.simulate(parameters)
      }
      puts "Manual config simulator took: #{bm.to_s}"

    elsif control[:autofit]
      bm = Benchmark.measure {
        parameters = simulator.fit(simulator.default_simulator_parameters)
        save_yaml_parameters(parameters, 'auto fit')
        simulator.simulate(parameters)
      }
      puts "Auto fitted simulator took: #{bm.to_s}"
    else
      bm = Benchmark.measure {
        simulator.simulate(simulator.default_simulator_parameters)
      }
      puts "Simulator took: #{bm.to_s}"
    end
  end

  def save_yaml_parameters(parameters, type)
    filename = "./Simulator/#{@school.name} simulator config #{type}.yaml"
    puts "Saving file #{filename}"
    File.open(filename, 'w') { |f| f.write(YAML.dump(parameters)) }
  end

  def config_files
    Dir["./Simulator/#{@school.name} simulator config*.yaml"]
  end

  def load_yaml(filename)
    puts "Loading file from #{filename}"
    YAML.load_file(filename)
  end

  def valid?
    !@school.aggregated_electricity_meters.nil?
  end

  def run_single_dashboard_page(single_page_config, mpan_mprn)
    puts "#{name} #{mpan_mprn}"
    single_page_config[:charts].each do |chart_name|
      run_chart(mpan_mprn.to_s, chart_name)
    end
  end
end
