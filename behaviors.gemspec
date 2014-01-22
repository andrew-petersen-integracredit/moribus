# -*- encoding: utf-8 -*-

$:.push File.expand_path("../lib", __FILE__)
require "behaviors/version"

Gem::Specification.new do |s|
  s.name        = "behaviors"
  s.version     = Behaviors::VERSION
  s.authors     = ["TMX Credit", "Artem Kuzko", "Zachary Belzer", "Sergey Potapov"]
  s.email       = ["rubygems@tmxcredit.com", "akuzko@sphereconsultinginc.com", "zbelzer@gmail.com", "blake131313@gmail.com"]
  s.homepage    = "https://github.com/TMXCredit/behaviors"
  s.licenses    = ["LICENSE"]
  s.summary     = %q{Introduces Aggregated and Tracked behavior to ActiveRecord::Base models}
  s.description = %q{Introduces Aggregated and Tracked behavior to ActiveRecord::Base models, as well
    as Macros and Extensions modules for more efficient usage. Effectively replaces
    both Aggregatable and Trackable modules.}

  s.rubyforge_project = "behaviors"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_dependency("rails",      "~> 3.2")
  s.add_dependency("power_enum", "~> 1.3")
  s.add_dependency("yard",       ">= 0")
  s.add_dependency("gemfury",    ">= 0")

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "timecop"
end
