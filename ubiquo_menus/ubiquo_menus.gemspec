# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ubiquo_menus/version"

Gem::Specification.new do |s|
  s.name        = "ubiquo_menus"
  s.version     = UbiquoMenus.version
  s.authors     = ["Jordi Beltran", "Albert Callarisa", "Bernat Foj", "Eric Garcia", "Felip Ladrón", "David Lozano", "Toni Reina", "Ramon Salvadó", "Arnau Sánchez"]
  s.homepage    = "http://www.ubiquo.me"
  s.summary     = %q{This gem provides the capability of managing application menus}
  s.description = %q{This gem provides the capability of managing application menus}

  s.rubyforge_project = "ubiquo_menus"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "ubiquo_core", "~> 0.9.0.b1"
  s.add_dependency "ubiquo_design", "~> 0.9.0.b1"

  s.add_development_dependency "sqlite3", "~> 1.3.5"
  s.add_development_dependency "mocha", "~> 0.10.0"

end
