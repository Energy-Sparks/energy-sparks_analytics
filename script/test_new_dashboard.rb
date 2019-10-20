require 'require_all'
require_relative '../lib/dashboard.rb'
require_rel '../test_support'



module Logging
  @logger = Logger.new('log/test-new-dashboard whiteways' + Time.now.strftime('%H %M') + '.log')
  logger.level = :debug
end

$SCHOOL_FACTORY = SchoolFactory.new

school_name = 'Whiteways Primary'

school = $SCHOOL_FACTORY.load_or_use_cached_meter_collection(:name, school_name, :analytics_db)

# would normally expect to recurse through DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:adult_analysis_page]
# but for the purposes of this example, pick up the definition directly
config = DashboardConfiguration::DASHBOARD_PAGE_GROUPS[:adult_analysis_page][:sub_pages][2][:sub_pages][0]

ap config

advice = config[:class].new(school)
advice.calculate

# direct access to variable for star rating and
# brief summary text on summary page
puts advice.rating
puts advice.out_of_hours_£

ap config[:class].front_end_template_variables # front end variables

# data for those variables
ap advice.front_end_template_data

# content: array of combinations of [
#   { type: :html,  content: html_string }      # advice header
#   { type: :chart, content: chart_definition } # chart
#   { type: :html,  content: html_string }      # advice header
# ]
# in the 1st version, the data is returned as triplets as it uses the
# legacy infrastructure, but will change going forward
advice.content
