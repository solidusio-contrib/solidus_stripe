# frozen_string_literal: true

module Spree
  class PaymentMethod
    class StripeCreditCard < Spree::PaymentMethod::CreditCard
      preference :secret_key, :string
      preference :publishable_key, :string
      preference :stripe_country, :string
      preference :v3_elements, :boolean
      preference :v3_intents, :boolean

      CARD_TYPE_MAPPING = {
        'American Express' => 'american_express',
        'Diners Club' => 'diners_club',
        'Visa' => 'visa'
      }.freeze

      delegate :create_intent, :update_intent, :confirm_intent, :show_intent, to: :gateway

      def stripe_config(order)
        {
          id: id,
          publishable_key: preferred_publishable_key
        }.tap do |config|
          if payment_request?
            config.merge!(
              payment_request: {
                country: preferred_stripe_country,
                currency: order.currency.downcase,
                label: "Payment for order #{order.number}",
                amount: (order.total * 100).to_i
              }
            )
          end
        end
      end

      def partial_name
        'stripe'
      end

      def v3_elements?
        !!preferred_v3_elements
      end

      def payment_request?
        v3_intents? && preferred_stripe_country.present?
      end

      def v3_intents?
        !!preferred_v3_intents
      end

      def gateway_class
        if v3_intents?
          ActiveMerchant::Billing::StripePaymentIntentsGateway
        else
          ActiveMerchant::Billing::StripeGateway
        end
      end

      def payment_profiles_supported?
        true
      end

      def purchase(money, creditcard, transaction_options)
        gateway.purchase(*options_for_purchase_or_auth(money, creditcard, transaction_options))
      end

      def authorize(money, creditcard, transaction_options)
        gateway.authorize(*options_for_purchase_or_auth(money, creditcard, transaction_options))
      end

      delegate :capture, to: :gateway

      def credit(money, _creditcard, response_code, _transaction_options)
        gateway.refund(money, response_code, {})
      end

      def void(response_code, _creditcard, _transaction_options)
        gateway.void(response_code, {})
      end

      def payment_intents_refund_reason
        Spree::RefundReason.where(name: Spree::Payment::Cancellation::DEFAULT_REASON).first_or_create
      end

      def try_void(payment)
        if v3_intents? && payment.completed?
          payment.refunds.create!(
            amount: payment.credit_allowed,
            reason: payment_intents_refund_reason
          ).response
        else
          void(payment.response_code, nil, nil)
        end
      end

      def cancel(response_code)
        gateway.void(response_code, {})
      end

      def create_profile(payment)
        return unless payment.source.gateway_customer_profile_id.nil?

        options = {
          email: payment.order.email,
          login: preferred_secret_key,
        }.merge! address_for(payment)

        source = update_source!(payment.source)
        if source.number.blank? && source.gateway_payment_profile_id.present?
          creditcard =
            if v3_intents?
              ActiveMerchant::Billing::StripeGateway::StripePaymentToken.new('id' => source.gateway_payment_profile_id)
            else
              source.gateway_payment_profile_id
            end
        else
          creditcard = source
        end

        response = gateway.store(creditcard, options)
        if response.success?
          if v3_intents?
            payment.source.update!(
              cc_type: payment.source.cc_type,
              gateway_customer_profile_id: response.params['customer'],
              gateway_payment_profile_id: response.params['id']
            )
          else
            payment.source.update!(
              cc_type: payment.source.cc_type,
              gateway_customer_profile_id: response.params['id'],
              gateway_payment_profile_id: response.params['default_source'] || response.params['default_card']
            )
          end
        else
          payment.send(:gateway_error, response.message)
        end
      end

      private

      # In this gateway, what we call 'secret_key' is the 'login'
      def options
        options = super
        options.merge(login: preferred_secret_key)
      end

      def options_for_purchase_or_auth(money, creditcard, transaction_options)
        options = {}
        options[:description] = "Solidus Order ID: #{transaction_options[:order_id]}"
        options[:currency] = transaction_options[:currency]
        options[:off_session] = true if v3_intents?

        if customer = creditcard.gateway_customer_profile_id
          options[:customer] = customer
        end
        if token_or_card_id = creditcard.gateway_payment_profile_id
          # The Stripe ActiveMerchant gateway supports passing the token directly as the creditcard parameter
          # The Stripe ActiveMerchant gateway supports passing the customer_id and credit_card id
          # https://github.com/Shopify/active_merchant/issues/770
          creditcard = token_or_card_id
        end
        [money, creditcard, options]
      end

      def address_for(payment)
        {}.tap do |options|
          if address = payment.order.bill_address
            options[:address] = {
              address1: address.address1,
              address2: address.address2,
              city: address.city,
              zip: address.zipcode
            }

            if country = address.country
              options[:address][:country] = country.name
            end

            if state = address.state
              options[:address].merge!(state: state.name)
            end
          end
        end
      end

      def update_source!(source)
        source.cc_type = CARD_TYPE_MAPPING[source.cc_type] if CARD_TYPE_MAPPING.include?(source.cc_type)
        source
      end
    end
  end
end
