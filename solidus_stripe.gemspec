# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'solidus_stripe/version'

# encoding: UTF-8

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "solidus_stripe"
  s.version     = SolidusStripe::VERSION
  s.summary     = "Stripe Payment Method for Solidus"
  s.description = s.summary
  s.required_ruby_version = ">= 2.2"

  s.author       = "Solidus Team"
  s.email        = "contact@solidus.io"
  s.homepage     = "https://solidus.io"
  s.license      = 'BSD-3'

  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"
  s.requirements << "none"

  s.add_dependency "solidus_core", [">= 2.3", "< 3"]
  s.add_dependency "solidus_support", ">= 0.3.1"

  # ActiveMerchant v1.58 through v1.59 introduced a breaking change
  # to the stripe gateway.
  #
  # This was resolved in v1.60, but we still need to skip 1.58 & 1.59.
  s.add_dependency "activemerchant", ">= 1.100" # includes "Stripe Payment Intents: Fix fallback for Store"
  s.add_dependency "stripe", ">= 5.10"

  s.add_development_dependency "capybara"
  s.add_development_dependency "capybara-screenshot"
  s.add_development_dependency "database_cleaner", "~> 1.5"
  s.add_development_dependency "factory_bot", "~> 4.4"
  s.add_development_dependency "gem-release", "~> 2.0"
  s.add_development_dependency "rspec-rails", "~> 3.2"
  s.add_development_dependency 'selenium-webdriver', '~> 3.142'
  s.add_development_dependency "simplecov"
  s.add_development_dependency "sqlite3"
end
