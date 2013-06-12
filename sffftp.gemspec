# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "sffftp/version"

Gem::Specification.new do |s|
  s.name        = "sffftp"
  s.version     = Sffftp::VERSION
  s.authors     = ["pacojp"]
  s.email       = ["paco.jp@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{automatically scp files in a specified folder}
  s.description = %q{automatically scp files in a specified folder}
  s.rubyforge_project = "sffftp"

  #s.add_dependency "batchbase",["0.0.4"]
  s.add_dependency "net-sftp"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
