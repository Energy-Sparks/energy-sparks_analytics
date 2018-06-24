require 'csv'
require 'logger'
require './holidays'
require './temperatures'
require './solarinsolence'
require './amrdata'
require './energygraphs'
require './metersandschools'
require './electricitySimulator'
require 'benchmark'

puts "========================================================================================"
holData = HolidayData.new()
holLoader = HolidayLoader.new('.\InputData\Holidays.csv',holData)
puts "Holiday data: #{holData.length}"
holidays = Holidays.new(holData)

puts "========================================================================================"
temperatures = Temperatures.new("temperatures")
TemperaturesLoader.new('.\InputData\temperatures.csv', temperatures)
puts "Temperatures: #{temperatures.length}"

puts "========================================================================================"
solarinsolence = SolarInsolence.new("solarinsolence")
SolarInsolenceLoader.new('.\InputData\solarinsolence.csv', solarinsolence)
puts "Solar Insolence: #{solarinsolence.length}"

puts "========================================================================================"
puts "Day of Week Aggregation"
amrData		= AMRData.new("electricity amr")
AMRLoader.new('.\InputData\FromeElectric1.csv', amrData)

puts "========================================================================================"

building = Building.new("Trinity Primary Main Building", "Frome", 1100, 300)
meter = Meter.new(building, amrData, :electricity)
fromeschool = School.new("Trinity Primary", "Frome", 1100, 300)
fromeschool.addElectricityMeter(meter)

puts "========================================================================================"
puts "Creating excel spreadsheet"
excel = EnergyGraphs.new('.\Results\energysimulatorresults.xlsx')

puts "========================================================================================"
puts  "calculating and getting date range for last academic year"
mostRecentAcademicYear = amrData.acaedmicYears(holidays)[0]

puts "========================================================================================"
puts  "electrical simulation"

applianceDefinitions = {
	:lighting 		=> {   :lumensPerWatt => 50.0,
						   :lumensPerM2	  => 450.0,
						   :percentOnAsFunctionOfSolarInsolance => {
								:solarInsolance => [   0, 100, 200, 300, 400, 500, 600,  700, 800, 900, 1000, 1100, 1200 ],
								:percentOfPeak  => [ 0.9, 0.8, 0.7, 0.6, 0.5, 0.2, 0.2, 0.15, 0.1, 0.1,  0.1,  0.1,  0.1 ],
							},
							:occupancyByHalfHour => [ 0,0,0,0,0,0,0,0,0,0,0,0,0,0.05,0.1,0.3,0.5,0.8,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0.8,0.6,0.4,0.2,0.15,0.15,0,0,0,0,0,0,0,0,0,0]
						},
	:ict				=> { 
								"Servers1" => {
									:type 					=> :server,
									:number					=>	2.0,
									:powerWattsEach			=>	300.0,
									:airConOverheadPercent	=> 0.2
								},
								"Servers2" => {
									:type 					=> :server,
									:number					=>	1.0,
									:powerWattsEach			=>	500.0,
									:airConOverheadPercent	=>  0.3
								},
								"Desktops" => {
									:type 						=> :desktop,
									:number						=>	20,
									:powerWattsEach				=>	100,
									:standbyWattsEach			=>	10,
									:usagePercentByTimeOfDay	=>	[ 0,0,0,0,0,0,0,0,0,0,0,0,0,0.05,0.1,0.3,0.5,0.8,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0.8,0.6,0.4,0.2,0.15,0.15,0,0,0,0,0,0,0,0,0,0],
									:weekends					=> true,		# left on standy at weekends
									:holidays					=> false		# left on standby during holidays
								},
								"Laptops" => {
									:type 						=> :laptop,
									:number						=>	20,
									:powerWattsEach				=>	30,
									:standbyWattsEach			=>	2,
									:usagePercentByTimeOfDay	=>	[ 0,0,0,0,0,0,0,0,0,0,0,0,0,0.05,0.1,0.3,0.5,0.8,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0.8,0.6,0.4,0.2,0.15,0.15,0,0,0,0,0,0,0,0,0,0]
									}
						},
	:boilerPumps		=> { 
							:heatingSeasonStartDates 	=> [ Date.new(2016, 10,  1),  Date.new(2017,11,5) ],
							:heatingSeasonEndDates 		=> [ Date.new(2017,  5, 14),  Date.new(2018, 5,1) ],
							:startTime					=> Time.new(2010,  1,  1,  5, 30, 0),		# Ruby doesn't have a time class, just DateTime, so the 2010/1/1 should be ignored
							:endTime					=> Time.new(2010,  1,  1,  17, 0, 0),		# ditto
							:pumpPower					=> 0.5,
							:weekends					=> false,
							:holidays					=> true,
							:frostProtectionTemp		=> 4
						},
	:securityLighting	=> {
							:controlType 	=> "Sunrise/Sunset",	# "Sunrise/Sunset" or "Ambient" or "Fixed Times"
							:sunriseTimes	=>	[ "08:05", "07:19", "06:19", "06:10", "05:14", "04:50", "05:09", "05:54", "06:43", "07:00", "07:26", "08:06" ], # by month - in string format as more compact than new Time - which it needs converting to
							:sunsetTimes	=>	[ "16:33", "17:27", "18:16", "20:08", "20:56", "21:30", "21:21", "20:32", "19:24", "18:17", "16:21", "16:03" ], # ideally front end calculates based on GEO location
							:fixedStartTime => "19:15",
							:fixedEndTime 	=> "07:20",
							:ambientThreshold => 50.0,
							:power			=>	3.0
						},
	:electricalheating	=> { },
	:kitchen			=> { 
							:startTime		=> Time.new(2010,  1,  1,  5, 30, 0),		# Ruby doesn't have a time class, just DateTime, so the 2010/1/1 should be ignored
							:endTime		=> Time.new(2010,  1,  1,  17, 0, 0),		# ditto
							:power			=> 4.0,
						},
	:summerAirConn		=> { 
							:startTime				=> Time.new(2010,  1,  1,  5, 30, 0),		# Ruby doesn't have a time class, just DateTime, so the 2010/1/1 should be ignored
							:endTime				=> Time.new(2010,  1,  1,  17, 0, 0),		# ditto
							:weekends				=> true,
							:holidays				=> false,
							:balancePointTemperature=> 19,										# centigrade
							:powerPerDegreeday		=> 0.5										# colling degree days > balancePointTemperature
						},
	:electricHotWater	=> { 
							:startTime				=> Time.new(2010,  1,  1,  9,  0, 0),		# Ruby doesn't have a time class, just DateTime, so the 2010/1/1 should be ignored
							:endTime				=> Time.new(2010,  1,  1,  16,30, 0),		# ditto
							:weekends				=> true,
							:holidays				=> false,
							:percentOfPupils		=> 0.5,										# often a its only a proportion of the pupils at a school has electric hot water, the rest are provided by ga
							:litresPerDayPerPupil	=> 5.0,										# assumes at 38C versus ambient of 15C, to give a deltaT of 23C
							:standbyPower			=> 0.1										# outside start and end times, but dependent on whether switched off during weekends and holidays, see other parameters
						},
	:floodLighting		=> { },
	:unaccountedForBaseload		=> { 
							:baseload		=> 2.5						
							},	
	:solarPV			=> { }
}

fromeSchool = School.new("Trinity School", "Frome BA11", 1100, 300)
						
simulator = ElectricitySimulator.new(mostRecentAcademicYear, holidays, temperatures, solarinsolence, fromeSchool)

simulator.simulate(applianceDefinitions)

excel.addData("Boiler Pumps", 					simulator.calcComponentsResults["Boiler Pumps"])
excel.addData("Security Lighting", 				simulator.calcComponentsResults["Security Lighting"])
excel.addData("Kitchen", 						simulator.calcComponentsResults["Kitchen"])
excel.addData("Air Conditioning", 				simulator.calcComponentsResults["Air Conditioning"])
excel.addData("Unaccounted For Baseload", 		simulator.calcComponentsResults["Unaccounted For Baseload"])

# puts simulator.calcComponentsResults

puts "========================================================================================"
puts "Week aggregation"

results = {}

time = Benchmark.measure {
	weekAggregator = AMRWeekDataAggregator.new(amrData, temperatures)
	weekAggregator.aggregate(mostRecentAcademicYear, holidays, "kWh", 1.0)
	results = weekAggregator.formatResults()
}

puts "day of week aggregation takes #{time}"
 
excel.addGraphAndData("WeekOfYear", results)


puts "========================================================================================"
puts "day type pie chart"

dtAggregator = AMRDayTypeDataAggregator.new(amrData)
dtAggregator.aggregate(mostRecentAcademicYear, holidays, "kWh", 1.0)
results = dtAggregator.formatResults()
excel.addGraphAndData("DayType", results)


excel.close
