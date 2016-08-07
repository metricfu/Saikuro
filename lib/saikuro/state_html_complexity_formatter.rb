class StateHTMLComplexityFormater < ParseStateFormater
  include HTMLStyleSheet

  def start(new_out=nil)
    reset_data
    @out = new_out if new_out
    @out.puts "<html><head><title>Cyclometric Complexity</title></head>"
    @out.puts style_sheet
    @out.puts "<body>"
  end

  def end
    @out.puts "</body>"
    @out.puts "</html>"
  end

  def start_class_compute_state(type_name,name,complexity,first_line,lines)
    @current = name
    @out.puts "<div class=\"class_complexity\">"
    @out.puts "<h2 class=\"class_name\">#{type_name} : #{name}</h2>"
    @out.puts "<div class=\"class_first_line\">First Line: #{first_line}</div>"
    @out.puts "<div class=\"class_total_complexity\">Total Complexity: #{complexity}</div>"
    @out.puts "<div class=\"class_total_lines\">Total Lines: #{lines}</div>"
    @out.puts "<table width=\"100%\" border=\"1\">"
    @out.puts "<tr><th>Method</th><th>Complexity</th><th>First Line</th><th># Lines</th></tr>"
  end

  def end_class_compute_state(name)
    @out.puts "</table>"
    @out.puts "</div>"
  end

  def def_compute_state(name, complexity, first_line, lines)
    return if @filter.ignore?(complexity)
    klass = warn_error?(complexity, name)
    @out.puts "<tr><td>#{name}</td><td#{klass}>#{complexity}</td><td>#{first_line}</td><td>#{lines}</td></tr>"
  end

end
