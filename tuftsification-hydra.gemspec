$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "tuftsification-hydra/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "tuftsification-hydra"
  s.version     = TuftsificationHydra::VERSION
  s.authors     = ["Mike Korcynski"]
  s.email       = ["Mike.Korcynski@tufts.edul"]
  s.homepage    = "http://dl.tufts.edu"
  s.summary     = "Base code needed to make a hydra head work with Tufts Content."
  s.description = "Base code needed to make a hydra head work with Tufts Content."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.20"
  s.add_dependency "chronic"
  s.add_dependency "titleize"
  s.add_dependency "settingslogic"
  s.add_dependency "image_size"

  # s.add_dependency "jquery-rails"

  s.add_development_dependency "sqlite3"
end
