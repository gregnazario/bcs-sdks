# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "bcs"
  spec.version       = "0.1.0"
  spec.authors       = ["BCS SDK Contributors"]
  spec.email         = ["bcs-sdk@example.com"]

  spec.summary       = "Binary Canonical Serialization (BCS) for Ruby"
  spec.description   = "A Ruby implementation of Binary Canonical Serialization (BCS), " \
                       "a deterministic binary serialization format."
  spec.homepage      = "https://github.com/bcs-sdks/bcs-sdks"
  spec.license       = "Apache-2.0"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bcs-sdks/bcs-sdks/tree/main/sdks/ruby"
  spec.metadata["changelog_uri"] = "https://github.com/bcs-sdks/bcs-sdks/blob/main/sdks/ruby/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end

  spec.require_paths = ["lib"]

  # Development dependencies
  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "rubocop-minitest", "~> 0.31"
  spec.add_development_dependency "rubocop-rake", "~> 0.6"
end
