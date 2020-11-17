# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

# Run Coverage report
require 'solidus_dev_support/rspec/coverage'

require File.expand_path('dummy/config/environment.rb', __dir__)

# Requires factories and other useful helpers defined in spree_core.
require 'solidus_dev_support/rspec/feature_helper'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].sort.each { |f| require f }

# Requires factories defined in lib/solidus_stripe/factories.rb
require 'solidus_stripe/factories'

# Requires card input helper defined in lib/solidus_stripe/testing_support/card_input_helper.rb
require 'solidus_stripe/testing_support/card_input_helper'

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  FactoryBot.find_definitions
  config.use_transactional_fixtures = false
  config.include SolidusAddressNameHelper, type: :feature
  config.include SolidusCardInputHelper, type: :feature
end
