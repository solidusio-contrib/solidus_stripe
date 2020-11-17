# frozen_string_literal: true

module SolidusStripe
  module Generators
    class InstallGenerator < Rails::Generators::Base
      class_option :auto_run_migrations, type: :boolean, default: false

      def add_javascripts
        append_file 'vendor/assets/javascripts/spree/frontend/all.js', "//= require spree/frontend/solidus_stripe\n"
      end

      def add_migrations
        run 'bin/rails railties:install:migrations FROM=solidus_stripe'
      end

      def run_migrations
        run_migrations = options[:auto_run_migrations] || ['', 'y', 'Y'].include?(ask('Would you like to run the migrations now? [Y/n]')) # rubocop:disable Metrics/LineLength
        if run_migrations
          run 'bin/rails db:migrate'
        else
          puts 'Skipping bin/rails db:migrate, don\'t forget to run it!' # rubocop:disable Rails/Output
        end
      end

      def populate_seed_data
        return unless options.auto_run_seeds?

        say_status :loading, 'stripe seed data'
        rake('db:seed:solidus_stripe')
      end
    end
  end
end
