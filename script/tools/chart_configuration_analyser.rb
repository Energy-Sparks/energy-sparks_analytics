require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'
# goes through all the charts in chart_configation.rb
# and analyses them for inheritance and configuraiton types

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

def resolve_chart(chart_name)
  chart_config = ChartManager::STANDARD_CHART_CONFIGURATION[chart_name]
  parents = []
  inherits_from(chart_name, parents)
  children = []
  children_of(chart_name, children)
  children
end

mapping = ChartManager::STANDARD_CHART_CONFIGURATION.keys.map do |chart_name|
  [chart_name, resolve_chart(chart_name).flatten]
end.to_h

# ap mapping
# ap mapping.length

manager = ChartManager.new(nil)
configs = ChartManager::STANDARD_CHART_CONFIGURATION.map do |chart_name, definition|
  [chart_name, manager.resolve_chart_inheritance(definition)]
end.to_h

stats = Hash.new{ |hash, key| hash[key] = Array.new }
configs.each do |_name, definition|
  definition.each do |key, value|
    stats[key].push(value)
  end
end

counted_stats = stats.map do |key, value|
  [key, value.each_with_object(Hash.new(0)) { |l, o| o[l] += 1 }]
end

# ap configs

# ap stats

ap counted_stats

