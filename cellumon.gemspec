# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name         = "cellumon"
  gem.version      = "0.1.6"
  gem.platform     = Gem::Platform::RUBY
  gem.summary      = "Monitor threads, processes, and states of Celluloid and its Actor System."
  gem.description  = "Thread summary and reporting actor, utility for finding leaks and monitoring."
  gem.licenses     = ["MIT"]

  gem.authors      = ["digitalextremist //"]
  gem.email        = ["code@extremist.digital"]
  gem.homepage     = "https://github.com/digitalextremist/cellumon"

  gem.required_ruby_version     = ">= 1.9.2"
  gem.required_rubygems_version = ">= 1.3.6"

  gem.files        = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|examples|spec|features)/}) }
  gem.require_path = "lib"
end
