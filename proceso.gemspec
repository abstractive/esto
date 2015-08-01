# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name         = "proceso"
  gem.version      = "0.6.0"
  gem.platform     = Gem::Platform::RUBY
  gem.summary      = "Monitor processes; uptime, threads and memory, and actor system states."
  gem.description  = "Process statistics, and utility for finding problems in Celluloid systems."
  gem.licenses     = ["MIT"]

  gem.authors      = ["digitalextremist //"]
  gem.email        = ["code@extremist.digital"]
  gem.homepage     = "https://github.com/abstractive/proceso"

  gem.required_ruby_version     = ">= 1.9.2"
  gem.required_rubygems_version = ">= 1.3.6"

  gem.files        = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|examples|spec|features)/}) }
  gem.require_path = "lib"
  gem.add_runtime_dependency "celluloid", ">= 0.17.0"
  gem.add_runtime_dependency "abstractive"
  gem.add_runtime_dependency "timespans"
end
