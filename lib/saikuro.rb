require "saikuro/version"

require "saikuro/html_style_sheet"

require "saikuro/result_index_generator"

require "saikuro/base_formater"
require "saikuro/token_counter_formater"
require "saikuro/parse_state_formater"
require "saikuro/html_token_counter_formater"
require "saikuro/state_html_complexity_formater"

require "saikuro/cli"

require 'irb/ruby-lex'
require 'yaml'

module Saikuro
end

#Returns the path without the file
def seperate_file_from_path(path)
  res = path.split("/")
  if res.size == 1
    ""
  else
    res[0..res.size - 2].join("/")
  end
end

def get_ruby_files(path)
  files = Array.new
  Find.find(path) do |f|
    if !FileTest.directory?(f)
      if f =~ /rb$/
        files<< f
      end
    end
  end
  files
end

# States to watch for
# once in def get the token after space, because it may also
# be something like + or << for operator overloading.

# Counts the number of tokens in each line.
class TokenCounter
  include RubyToken

  attr_reader :current_file

  def initialize
    @files = Hash.new
    @tokens_per_line = Hash.new(0)
    @current_file = ""
  end

  # Mark file to associate with the token count.
  def set_current_file(file)
    @current_file = file
    @tokens_per_line = Hash.new(0)
    @files[@current_file] = @tokens_per_line
  end

  # Iterate through all tracked files, passing the
  # the provided formater the token counts.
  def list_tokens_per_line(formater)
    formater.start_count(@files.size)
    @files.each do |fname, tok_per_line|
      formater.start_file(fname)
      tok_per_line.sort.each do |line,num|
	    formater.line_token_count(line,num)
      end
      formater.end_file
    end
  end

  # Count the token for the passed line.
  def count_token(line_no,token)
    case token
    when TkSPACE, TkNL, TkRD_COMMENT
      # Do not count these as tokens
    when TkCOMMENT
      # Ignore this only for comments in a statement?
      # Ignore TkCOLON,TkCOLON2  and operators? like "." etc..
    when TkRBRACK, TkRPAREN, TkRBRACE
      # Ignore the closing of an array/index/hash/paren
      # The opening is counted, but no more.
      # Thus [], () {} is counted as 1 token not 2.
    else
      # may want to filter out comments...
      @tokens_per_line[line_no] += 1
    end
  end

end

# Main class and structure used to compute the
# cyclomatic complexity of Ruby programs.
class ParseState
  include RubyToken
  attr_accessor :name, :children, :complexity, :parent, :lines

  @@top_state = nil
  def ParseState.make_top_state()
    @@top_state = ParseState.new(nil)
    @@top_state.name = "__top__"
    @@top_state
  end

  @@token_counter = TokenCounter.new
  def ParseState.set_token_counter(counter)
    @@token_counter = counter
  end
  def ParseState.get_token_counter
    @@token_counter
  end

  def initialize(lexer,parent=nil)
    @name = ""
    @children = Array.new
    @complexity = 0
    @parent = parent
    @lexer = lexer
    @run = true
    # To catch one line def statements, We always have one line.
    @lines = 0
    @last_token_line_and_char = Array.new
  end

  def top_state?
    self == @@top_state
  end

  def lexer=(lexer)
    @run = true
    @lexer = lexer
  end

  def make_state(type,parent = nil)
    cstate = type.new(@lexer,self)
    parent.children<< cstate
    cstate
  end

  def calc_complexity
    complexity = @complexity
    children.each do |child|
      complexity += child.calc_complexity
    end
    complexity
  end

  def calc_lines
    lines = @lines
    children.each do |child|
      lines += child.calc_lines
    end
    lines
  end

  def compute_state(formater)
    if top_state?
      compute_state_for_global(formater)
    end

    @children.each do |s|
      s.compute_state(formater)
    end
  end

  def compute_state_for_global(formater)
    global_def, @children = @children.partition do |s|
      !s.kind_of?(ParseClass)
    end
    return if global_def.empty?
    gx = global_def.inject(0) { |c,s| s.calc_complexity }
    gl = global_def.inject(0) { |c,s| s.calc_lines }
    formater.start_class_compute_state("Global", "", gx, gl)
    global_def.each do |s|
      s.compute_state(formater)
    end
    formater.end_class_compute_state("")
  end

  # Count the tokens parsed if true else ignore them.
  def count_tokens?
    true
  end

  def parse
    while @run do
      tok = @lexer.token
      @run = false if tok.nil?
      if lexer_loop?(tok)
        STDERR.puts "Lexer loop at line : #{@lexer.line_no} char #{@lexer.char_no}."
        @run = false
      end
      @last_token_line_and_char<< [@lexer.line_no.to_i, @lexer.char_no.to_i, tok]
      if $VERBOSE
        puts "DEBUG: #{@lexer.line_no} #{tok.class}:#{tok.name if tok.respond_to?(:name)}"
      end
      @@token_counter.count_token(@lexer.line_no, tok) if count_tokens?
      parse_token(tok)
    end
  end

  # Ruby-Lexer can go into a loop if the file does not end with a newline.
  def lexer_loop?(token)
    return false if @last_token_line_and_char.empty?
    loop_flag = false
    last = @last_token_line_and_char.last
    line = last[0]
    char = last[1]
    ltok = last[2]

    if ( (line == @lexer.line_no.to_i) &&
           (char == @lexer.char_no.to_i) &&
           (ltok.class == token.class) )
      # We are potentially in a loop
      if @last_token_line_and_char.size >= 3
        loop_flag = true
      end
    else
      # Not in a loop so clear stack
      @last_token_line_and_char = Array.new
    end

    loop_flag
  end

  def do_begin_token(token)
    make_state(EndableParseState, self)
  end

  def do_class_token(token)
    make_state(ParseClass,self)
  end

  def do_module_token(token)
    make_state(ParseModule,self)
  end

  def do_def_token(token)
    make_state(ParseDef,self)
  end

  def do_constant_token(token)
    nil
  end

  def do_identifier_token(token)
    if (token.name == "__END__" && token.char_no.to_i == 0)
      # The Ruby code has stopped and the rest is data so cease parsing.
      @run = false
    end
    nil
  end

  def do_right_brace_token(token)
    nil
  end

  def do_end_token(token)
    end_debug
    nil
  end

  def do_block_token(token)
    make_state(ParseBlock,self)
  end

  def do_conditional_token(token)
    make_state(ParseCond,self)
  end

  def do_conditional_do_control_token(token)
    make_state(ParseDoCond,self)
  end

  def do_case_token(token)
    make_state(EndableParseState, self)
  end

  def do_one_line_conditional_token(token)
    # This is an if with no end
    @complexity += 1
    #STDOUT.puts "got IF_MOD: #{self.to_yaml}" if $VERBOSE
    #if state.type != "class" && state.type != "def" && state.type != "cond"
    #STDOUT.puts "Changing IF_MOD Parent" if $VERBOSE
    #state = state.parent
    #@run = false
    nil
  end

  def do_else_token(token)
    STDOUT.puts "Ignored/Unknown Token:#{token.class}" if $VERBOSE
    nil
  end

  def do_comment_token(token)
    make_state(ParseComment, self)
  end

  def do_symbol_token(token)
    make_state(ParseSymbol, self)
  end

  def parse_token(token)
    state = nil
    case token
    when TkCLASS
      state = do_class_token(token)
    when TkMODULE
      state = do_module_token(token)
    when TkDEF
      state = do_def_token(token)
    when TkCONSTANT
      # Nothing to do with a constant at top level?
      state = do_constant_token(token)
    when TkIDENTIFIER,TkFID
      # Nothing to do at top level?
      state = do_identifier_token(token)
    when TkRBRACE
      # Nothing to do at top level
      state = do_right_brace_token(token)
    when TkEND
      state = do_end_token(token)
      # At top level this might be an error...
    when TkDO,TkfLBRACE
      state = do_block_token(token)
    when TkIF,TkUNLESS
      state = do_conditional_token(token)
    when TkWHILE,TkUNTIL,TkFOR
      state = do_conditional_do_control_token(token)
    when TkELSIF #,TkELSE
      @complexity += 1
    when TkELSE
      # Else does not increase complexity
    when TkCASE
      state = do_case_token(token)
    when TkWHEN
      @complexity += 1
    when TkBEGIN
      state = do_begin_token(token)
    when TkRESCUE
      # Maybe this should add complexity and not begin
      @complexity += 1
    when TkIF_MOD, TkUNLESS_MOD, TkUNTIL_MOD, TkWHILE_MOD, TkQUESTION
      state = do_one_line_conditional_token(token)
    when TkNL
      #
      @lines += 1
    when TkRETURN
      # Early returns do not increase complexity as the condition that
      # calls the return is the one that increases it.
    when TkCOMMENT
      state = do_comment_token(token)
    when TkSYMBEG
      state = do_symbol_token(token)
    when TkError
      STDOUT.puts "Lexer received an error for line #{@lexer.line_no} char #{@lexer.char_no}"
    else
      state = do_else_token(token)
    end
    state.parse if state
  end

  def end_debug
    STDOUT.puts "got an end: #{@name} in #{self.class.name}" if $VERBOSE
    if @parent.nil?
      STDOUT.puts "DEBUG: Line #{@lexer.line_no}"
      STDOUT.puts "DEBUG: #{@name}; #{self.class}"
      # to_yaml can cause an infinite loop?
      #STDOUT.puts "TOP: #{@@top_state.to_yaml}"
      #STDOUT.puts "TOP: #{@@top_state.inspect}"

      # This may not be an error?
      #exit 1
    end
  end

end

# Read and consume tokens in comments until a new line.
class ParseComment < ParseState

  # While in a comment state do not count the tokens.
  def count_tokens?
    false
  end

  def parse_token(token)
    if token.is_a?(TkNL)
      @lines += 1
      @run = false
    end
  end
end

class ParseSymbol < ParseState
  def initialize(lexer, parent = nil)
    super
    STDOUT.puts "STARTING SYMBOL" if $VERBOSE
  end

  def parse_token(token)
    STDOUT.puts "Symbol's token is #{token.class}" if $VERBOSE
    # Consume the next token and stop
    @run = false
    nil
  end
end

class EndableParseState < ParseState
  def initialize(lexer,parent=nil)
    super(lexer,parent)
    STDOUT.puts "Starting #{self.class}" if $VERBOSE
  end

  def do_end_token(token)
    end_debug
    @run = false
    nil
  end
end

class ParseClass < EndableParseState
  def initialize(lexer,parent=nil)
    super(lexer,parent)
    @type_name = "Class"
  end

  def do_constant_token(token)
    @name = token.name if @name.empty?
    nil
  end

  def compute_state(formater)
    # Seperate the Module and Class Children out
    cnm_children, @children = @children.partition do |child|
      child.kind_of?(ParseClass)
    end

    formater.start_class_compute_state(@type_name,@name,self.calc_complexity,self.calc_lines)
    super(formater)
    formater.end_class_compute_state(@name)

    cnm_children.each do |child|
      child.name = @name + "::" + child.name
      child.compute_state(formater)
    end
  end
end

class ParseModule < ParseClass
  def initialize(lexer,parent=nil)
    super(lexer,parent)
    @type_name = "Module"
  end
end

class ParseDef < EndableParseState

  def initialize(lexer,parent=nil)
    super(lexer,parent)
    @complexity = 1
    @looking_for_name = true
    @first_space = true
  end

  # This way I don't need to list all possible overload
  # tokens.
  def create_def_name(token)
    case token
    when TkSPACE
      # mark first space so we can stop at next space
      if @first_space
        @first_space = false
      else
        @looking_for_name = false
      end
    when TkNL,TkLPAREN,TkfLPAREN,TkSEMICOLON
      # we can also stop at a new line or left parenthesis
      @looking_for_name = false
    when TkDOT
      @name<< "."
    when TkCOLON2
      @name<< "::"
    when TkASSIGN
      @name<< "="
    when TkfLBRACK
      @name<< "["
    when TkRBRACK
      @name<< "]"
    else
      begin
        @name<< token.name.to_s
          rescue Exception => err
        #what is this?
        STDOUT.puts @@token_counter.current_file
        STDOUT.puts @name
        STDOUT.puts token.inspect
        STDOUT.puts err.message
        exit 1
      end
    end
  end

  def parse_token(token)
    if @looking_for_name
      create_def_name(token)
    end
    super(token)
  end

  def compute_state(formater)
    formater.def_compute_state(@name, self.calc_complexity, self.calc_lines)
    super(formater)
  end
end

class ParseCond < EndableParseState
  def initialize(lexer,parent=nil)
    super(lexer,parent)
    @complexity = 1
  end
end

class ParseDoCond < ParseCond
  def initialize(lexer,parent=nil)
    super(lexer,parent)
    @looking_for_new_line = true
  end

  # Need to consume the do that can appear at the
  # end of these control structures.
  def parse_token(token)
    if @looking_for_new_line
      if token.is_a?(TkDO)
        nil
      else
        if token.is_a?(TkNL)
          @looking_for_new_line = false
        end
        super(token)
      end
    else
      super(token)
    end
  end

end

class ParseBlock < EndableParseState

  def initialize(lexer,parent=nil)
    super(lexer,parent)
    @complexity = 1
    @lbraces = Array.new
  end

  # Because the token for a block and hash right brace is the same,
  # we need to track the hash left braces to determine when an end is
  # encountered.
  def parse_token(token)
    if token.is_a?(TkLBRACE)
      @lbraces.push(true)
    elsif token.is_a?(TkRBRACE)
      if @lbraces.empty?
        do_right_brace_token(token)
        #do_end_token(token)
      else
        @lbraces.pop
      end
    else
      super(token)
    end
  end

  def do_right_brace_token(token)
    # we are done ? what about a hash in a block :-/
    @run = false
    nil
  end

end

# ------------ END Analyzer logic ------------------------------------

class Filter
  attr_accessor :limit, :error, :warn

  def initialize(limit = -1, error = 11, warn = 8)
    @limit = limit
    @error = error
    @warn = warn
  end

  def ignore?(count)
    count < @limit
  end

  def warn?(count)
    count >= @warn
  end

  def error?(count)
    count >= @error
  end

end

module Saikuro
  def Saikuro.analyze(files, state_formater, token_count_formater, output_dir)

    idx_states = Array.new
    idx_tokens = Array.new

    # parse each file
    files.each do |file|
      begin
        STDOUT.puts "Parsing #{file}"
        # create top state
        top = ParseState.make_top_state
        STDOUT.puts "TOP State made" if $VERBOSE
        token_counter = TokenCounter.new
        ParseState.set_token_counter(token_counter)
        token_counter.set_current_file(file)

        STDOUT.puts "Setting up Lexer" if $VERBOSE
        lexer = RubyLex.new
        # Turn of this, because it aborts when a syntax error is found...
        lexer.exception_on_syntax_error = false
        lexer.set_input(File.new(file,"r"))
        top.lexer = lexer
        STDOUT.puts "Parsing" if $VERBOSE
        top.parse


        fdir_path = seperate_file_from_path(file)
        FileUtils.makedirs("#{output_dir}/#{fdir_path}")

        if state_formater
          # output results
          state_io = StringIO.new
          state_formater.start(state_io)
          top.compute_state(state_formater)
          state_formater.end

          fname = "#{file}_cyclo.html"
          puts "writing cyclomatic #{file}" if $VERBOSE
          File.open("#{output_dir}/#{fname}","w") do |f|
            f.write state_io.string
          end
          idx_states<< [
            fname,
            state_formater.warnings.dup,
            state_formater.errors.dup,
          ]
        end

        if token_count_formater
          token_io = StringIO.new
          token_count_formater.start(token_io)
          token_counter.list_tokens_per_line(token_count_formater)
          token_count_formater.end

          fname = "#{file}_token.html"
          puts "writing token #{file}" if $VERBOSE
          File.open("#{output_dir}/#{fname}","w") do |f|
            f.write token_io.string
          end
          idx_tokens<< [
            fname,
            token_count_formater.warnings.dup,
            token_count_formater.errors.dup,
          ]
        end

      rescue RubyLex::SyntaxError => synerr
        STDOUT.puts "Lexer error for file #{file} on line #{lexer.line_no}"
        STDOUT.puts "#{synerr.class.name} : #{synerr.message}"
      rescue StandardError => err
        STDOUT.puts "Error while parsing file : #{file}"
        STDOUT.puts err.class,err.message,err.backtrace.join("\n")
      rescue Exception => ex
        STDOUT.puts "Error while parsing file : #{file}"
        STDOUT.puts ex.class,ex.message,ex.backtrace.join("\n")
      end
    end

    [idx_states, idx_tokens]
  end
end
