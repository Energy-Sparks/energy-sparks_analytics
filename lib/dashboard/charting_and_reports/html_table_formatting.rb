class HtmlTableFormatting
  def initialize(header, rows, totals_row = false)
    @header = header
    @rows = rows
    @total_row = @total_row
  end

  def html
    template = %{
      <p>
        <table class="table table-striped table-sm">
          <% unless @header.nil? %>
            <thead>
              <tr class="thead-dark">
                <% @header.each do |header_titles| %>
                  <th scope="col"> <%= header_titles.to_s %> </th>
                <% end %>
              </tr>
            </thead>
          <% end %>
          <tbody>
            <% @rows.each do |row| %>
              <tr>
                <% row.each do |val| %>
                  <td> <%= val %> </td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
          <% if @totals_row %>
            <tr class="table-success">
            <% @totals_row.each do |total| %>
              <th scope="col"> <%= total.to_s %> </th>
            <% end %>
            </tr>
          <% end %>
        </table>
      </p>
    }.gsub(/^  /, '')

    generate_html(template, binding)
  end

  def generate_html(template, binding)
    begin
      rhtml = ERB.new(template)
      rhtml.result(binding)
    rescue StandardError => e
      logger.error "Error generating html for #{self.class.name}"
      logger.error e.message
      logger.error e.backtrace
      '<div class="alert alert-danger" role="alert"><p>Error generating advice</p></div>'
    end
  end
end