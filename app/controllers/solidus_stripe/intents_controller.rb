# frozen_string_literal: true

module SolidusStripe
  class IntentsController < Spree::BaseController
    include Spree::Core::ControllerHelpers::Order

    def create_intent
      @intent = create_payment_intent
      generate_payment_response
    end

    def create_payment
      create_payment_service = SolidusStripe::CreateIntentsPaymentService.new(
        params[:stripe_payment_intent_id],
        stripe,
        self
      )

      if create_payment_service.call
        render json: { success: true }
      else
        render json: { error: "Could not create payment" }, status: :internal_server_error
      end
    end

    private

    def stripe
      @stripe ||= Spree::PaymentMethod::StripeCreditCard.find(params[:spree_payment_method_id])
    end

    def generate_payment_response
      response = @intent.params
      status = response['status']
      # Note that if your API version is before 2019-02-11, 'requires_action'
      # appears as 'requires_source_action'.
      require_action_list = %w[requires_source_action requires_action]

      if require_action_list.include?(status) && response['next_action']['type'] == 'use_stripe_sdk'
        render json: {
          requires_action: true,
          stripe_payment_intent_client_secret: response['client_secret']
        }
      elsif status == 'requires_capture'
        render json: {
          success: true,
          requires_capture: true,
          stripe_payment_intent_id: response['id']
        }
      else
        render json: { error: response['error']['message'] }, status: :internal_server_error
      end
    end

    def create_payment_intent
      stripe.create_intent(
        (current_order.total * 100).to_i,
        params[:stripe_payment_method_id],
        description: "Solidus Order ID: #{current_order.number} (pending)",
        currency: current_order.currency,
        confirmation_method: 'automatic',
        capture_method: 'manual',
        confirm: true,
        setup_future_usage: 'off_session',
        metadata: { order_id: current_order.id }
      )
    end
  end
end
