# frozen_string_literal: true

module SolidusStripe
  class CreateIntentsPaymentService
    attr_reader :intent_id, :stripe, :controller

    delegate :request, :current_order, :params, to: :controller

    def initialize(intent_id, stripe, controller)
      @intent_id, @stripe, @controller = intent_id, stripe, controller
    end

    def call
      invalidate_previous_payment_intents_payments
      if (payment = create_payment)
        description = "Solidus Order ID: #{payment.gateway_order_identifier}"
        stripe.update_intent(nil, intent_id, nil, description: description)
        true
      else
        invalidate_current_payment_intent
        false
      end
    end

    private

    def intent
      @intent ||= stripe.show_intent(intent_id, {})
    end

    def invalidate_current_payment_intent
      stripe.cancel(intent_id)
    end

    def invalidate_previous_payment_intents_payments
      return unless stripe.v3_intents?

      current_order.payments.pending.where(payment_method: stripe).find_each(&:void_transaction!)
    end

    def create_payment
      Spree::OrderUpdateAttributes.new(
        current_order,
        payment_params,
        request_env: request.headers.env
      ).apply

      created_payment = Spree::Payment.find_by(response_code: intent_id)
      created_payment&.tap { |payment| payment.update!(state: :pending) }
    end

    def payment_params
      {
        payments_attributes: [{
          payment_method_id: stripe.id,
          amount: current_order.total,
          response_code: intent_id,
          source_attributes: {
            month: intent_card['exp_month'],
            year: intent_card['exp_year'],
            cc_type: intent_card['brand'],
            last_digits: intent_card['last4'],
            gateway_payment_profile_id: intent_customer_profile,
            name: card_holder_name || address_full_name,
            address_attributes: address_attributes
          }
        }]
      }
    end

    def intent_card
      intent_data['payment_method_details']['card']
    end

    def intent_customer_profile
      intent.params['payment_method']
    end

    def card_holder_name
      (html_payment_source_data['name'] || intent_data['billing_details']['name']).presence
    end

    def intent_data
      intent.params['charges']['data'][0]
    end

    def form_data
      params[:form_data]
    end

    def html_payment_source_data
      if form_data.is_a?(String)
        data = Rack::Utils.parse_nested_query(form_data)
        data['payment_source'][stripe.id.to_s]
      else
        {}
      end
    end

    def address_attributes
      html_payment_source_data['address_attributes'] ||
      SolidusStripe::AddressFromParamsService.new(form_data).call.attributes
    end

    def address_full_name
      current_order.bill_address&.full_name || form_data[:recipient]
    end

    def update_stripe_payment_description
      description = "Solidus Order ID: #{payment.gateway_order_identifier}"
      stripe.update_intent(nil, intent_id, nil, description: description)
    end
  end
end
