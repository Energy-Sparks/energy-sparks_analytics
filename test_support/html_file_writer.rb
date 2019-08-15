# writes html advice snippets included in the output
# of chart_manager to a file for testing purposes
class HtmlFileWriter
  def initialize(school_name)
    filename = File.join(File.dirname(__FILE__), '../Results/') + school_name + ' - advice.html'
    @file = File.new(filename, 'w')
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
