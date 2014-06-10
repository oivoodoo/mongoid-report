# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mongoid/report/version'

Gem::Specification.new do |spec|
  spec.name          = "mongoid-report"
  spec.version       = Mongoid::Report::VERSION
  spec.authors       = ["Alexandr Korsak"]
  spec.email         = ["alex.korsak@gmail.com"]
  spec.summary       = %q{Easily build mongoid reports using aggregation framework}
  spec.description   = %q{Easily build mongoid reports using aggregation frameworkk}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'mongoid', '> 3.0.1'
  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
end
