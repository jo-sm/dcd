# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "dcd"
  spec.version       = "0.0.1"
  spec.authors       = ["Joshua Smock"]
  spec.email         = ["joshuasmock@gmail.com"]

  spec.summary       = %q{DCD is a simple parser for CHARMM and X-PLOR binary trajectory files}
  spec.homepage      = "https://github.com/jo-sm/dcd"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12.a"
  spec.add_development_dependency "rake", "~> 10.0"
end
