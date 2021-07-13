class ActivityLists

  def self.unorder_activity_list(activity_group)
    to_unordered_html_list(activities_links_html(activity_group))
  end

  def self.activities_links_html(activity_group)
    activities[activity_group].map { |activity| activity_reference_html(activity) }
  end

  def self.activities
    {
      baseload: [
        {
          name:   'Use appliance monitors to understand the energy use of individual appliances',
          number: 77
        },
        {
          name:   'Carry out a spot check to see if lights or electrical items are left on after school',
          number: 47
        },
      ]
    }
  end

  def self.to_unordered_html_list(items)
    html = '<ul>'
    items.each do |item|
      html += "<li> #{item}</li>"
    end
    html += '</ul>'
  end

  def self.activity_reference_html(activity)
    link = %(
      <a href="https://energysparks.uk/activity_types/<%= activity[:number] %>" target ="_blank"><%= activity[:name] %></a>
    )
    ERB.new(link).result(binding)
  end
end
