# frozen_string_literal: true

module SolidusStripe
  class AddressFromParamsService
    attr_reader :address_params, :user

    def initialize(address_params, user = nil)
      @address_params, @user = address_params, user
    end

    def call
      if user
        user.addresses.find_or_initialize_by(attributes)
      else
        Spree::Address.new(attributes)
      end
    end

    private

    def attributes
      @attributes ||= begin
        default_attributes.tap do |attributes|
          # possibly anonymized attributes:
          phone = address_params[:phone]
          lines = address_params[:addressLine]
          names = address_params[:recipient].split(' ')

          attributes.merge!(
            state_id: state&.id,
            firstname: names.first,
            lastname: names.last,
            phone: phone,
            address1: lines.first,
            address2: lines.second
          ).reject! { |_, value| value.blank? }
        end
      end
    end

    def country
      @country ||= Spree::Country.find_by(iso: address_params[:country])
    end

    def state
      @state ||= begin
        region = address_params[:region]
        country.states.find_by(abbr: region) || country.states.find_by(name: region)
      end
    end

    def default_attributes
      {
        country_id: country.id,
        city: address_params[:city],
        zipcode: address_params[:postalCode]
      }
    end
  end
end
