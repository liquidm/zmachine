# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "zmachine"
  spec.version       = "0.3.2"
  spec.authors       = ["LiquidM, Inc."]
  spec.email         = ["opensource@liquidm.com"]
  spec.description   = %q{pure JRuby multi-threaded mostly EventMachine compatible event loop}
  spec.summary       = %q{pure JRuby multi-threaded mostly EventMachine compatible event loop}
  spec.homepage      = "https://github.com/liquidm/zmachine"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "liquid-ext"
end
