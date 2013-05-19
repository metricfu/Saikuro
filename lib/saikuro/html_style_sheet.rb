module Saikuro
  module HTMLStyleSheet
    def HTMLStyleSheet.style_sheet
      out = StringIO.new

      out.puts "<style>"
      out.puts 'body {'
      out.puts '  margin: 20px;'
      out.puts '  padding: 0;'
      out.puts '  font-size: 12px;'
      out.puts '  font-family: bitstream vera sans, verdana, arial, sans serif;'
      out.puts '  background-color: #efefef;'
      out.puts '}'
      out.puts ''
      out.puts 'table { '
      out.puts '  border-collapse: collapse;'
      out.puts '  /*border-spacing: 0;*/'
      out.puts '  border: 1px solid #666;'
      out.puts '  background-color: #fff;'
      out.puts '  margin-bottom: 20px;'
      out.puts '}'
      out.puts ''
      out.puts 'table, th, th+th, td, td+td  {'
      out.puts '  border: 1px solid #ccc;'
      out.puts '}'
      out.puts ''
      out.puts 'table th {'
      out.puts '  font-size: 12px;'
      out.puts '  color: #fc0;'
      out.puts '  padding: 4px 0;'
      out.puts '  background-color: #336;'
      out.puts '}'
      out.puts ''
      out.puts 'th, td {'
      out.puts '  padding: 4px 10px;'
      out.puts '}'
      out.puts ''
      out.puts 'td {  '
      out.puts '  font-size: 13px;'
      out.puts '}'
      out.puts ''
      out.puts '.class_name {'
      out.puts '  font-size: 17px;'
      out.puts '  margin: 20px 0 0;'
      out.puts '}'
      out.puts ''
      out.puts '.class_complexity {'
      out.puts 'margin: 0 auto;'
      out.puts '}'
      out.puts ''
      out.puts '.class_complexity>.class_complexity {'
      out.puts '  margin: 0;'
      out.puts '}'
      out.puts ''
      out.puts '.class_total_complexity, .class_total_lines, .start_token_count, .file_count {'
      out.puts '  font-size: 13px;'
      out.puts '  font-weight: bold;'
      out.puts '}'
      out.puts ''
      out.puts '.class_total_complexity, .class_total_lines {'
      out.puts '  color: #c00;'
      out.puts '}'
      out.puts ''
      out.puts '.start_token_count, .file_count {'
      out.puts '  color: #333;'
      out.puts '}'
      out.puts ''
      out.puts '.warning {'
      out.puts '  background-color: yellow;'
      out.puts '}'
      out.puts ''
      out.puts '.error {'
      out.puts '  background-color: #f00;'
      out.puts '}'
      out.puts "</style>"

      out.string
    end

    def style_sheet
      HTMLStyleSheet.style_sheet
    end
  end
end

