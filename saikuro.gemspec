# -*- coding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "saikuro/version"

Gem::Specification.new do |s|
  s.name = "Saikuro"
  s.version = Saikuro::VERSION
  s.author = ["Zev Blut", "Roman V. Babenko", "David Barri"]
  s.email = ["zb@ubit.com", "romanvbabenko@gmail.com", "japgolly@gmail.com"]
  s.homepage = ""
  s.rubyforge_project = 'Saikuro'
  s.platform = Gem::Platform::RUBY
  s.summary = "Saikuro is a Ruby cyclomatic complexity analyzer."
  s.description = %q{When given Ruby source code Saikuro will generate a report listing the cyclomatic complexity of each method found.  In addition, Saikuro counts the number of lines per method and can generate a listing of the number of tokens on each line of code.}

  s.files= Dir['{bin,lib}/**/*']
  s.test_files= Dir['{test,spec,tests,features}/**/*']
  s.executables = ['saikuro']
  s.require_paths = ["lib"]

  s.has_rdoc = true
  s.extra_rdoc_files = ["README"]
end
