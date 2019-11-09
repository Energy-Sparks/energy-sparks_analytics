# writes html advice snippets included in the output
# of chart_manager to a file for testing purposes
class HtmlFileWriter
  FRONTEND_CSS = '<link rel="stylesheet" media="screen" href="https://fonts.googleapis.com/css?family=Open+Sans|Quicksand:300,500,700&amp;display=swap" />
  <link rel="stylesheet" media="all" href="https://cdn.energysparks.uk/static-assets/application-f2535905cd7274d6e4ffd9b4614323b1e11bbe6445bca5828b642a18516b9160.css" />'
  def initialize(school_name, frontend_css = true)
    filename = File.join(File.dirname(__FILE__), '../Results/') + school_name + ' - advice.html'
    @file = File.new(filename, 'w')
    @file.write(FRONTEND_CSS) if frontend_css
    @file.write("<html><h1>#{school_name}</h1></html>")
  end

  def write_header(text)
    @file.write("<html><h1>#{text}</h1></html>")
  end

  def write_header_footer(chart_name, header, footer)
    @file.write("<html><h1>#{chart_name}</h1></html>") unless chart_name.nil?
    @file.write(header) unless header.nil?
    @file.write("<html><h2>Chart #{chart_name} inserted here</h2></html>")
    @file.write(footer) unless footer.nil?
  end

  def write(html)
    @file.write(html)
  end

  def close
    @file.close
  end
end
