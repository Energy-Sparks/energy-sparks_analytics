require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
# prints parents and childdren of given chart

chart_name = :group_by_week_electricity



puts "Analysing parents and children of #{chart_name}"

def inherits_from(chart_name, list)
  chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name]
  if chart_config.key?(:inherits_from)
    list.push(chart_config[:inherits_from])
    inherits_from(chart_config[:inherits_from], list)
  end
end

def children_of(chart_name, list)
  immediate_children = ChartManager::STANDARD_CHART_CONFIGURATION.select do |_name, config|
    config.key?(:inherits_from) && config[:inherits_from] == chart_name
  end
  list.push(immediate_children.keys) unless immediate_children.empty?
  immediate_children.each_key do |child_chart_name|
    children_of(child_chart_name, list)
  end
end

chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name]
parents = []
inherits_from(chart_name, parents)
puts "Parents:"
ap parents
children = []
children_of(chart_name, children)
puts "Children:"
ap children

