# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'flagset/version'

Gem::Specification.new do |spec|
  spec.name          = "flagset"
  spec.version       = Flagset::VERSION
  spec.authors       = ["Yusuke Takeuchi"]
  spec.email         = ["v.takeuchi@gmail.com"]

  spec.summary       = %q{Module to define classes respresenting a set of flags.}
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/YusukeTakeuchi/flagset"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "equalizer"
end
