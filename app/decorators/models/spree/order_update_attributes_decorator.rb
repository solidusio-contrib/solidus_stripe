# frozen_string_literal: true

module Spree
  module OrderUpdateAttributesDecorator
    def assign_payments_attributes
      return if payments_attributes.empty?
      return if adding_new_stripe_payment_intents_card?

      stripe_intents_pending_payments.each(&:void_transaction!)

      super
    end

    private

    def adding_new_stripe_payment_intents_card?
      paying_with_stripe_intents? && stripe_intents_pending_payments.any?
    end

    def stripe_intents_pending_payments
      @stripe_intents_pending_payments ||= order.payments.valid.select do |payment|
        payment_method = payment.payment_method
        payment.pending? && stripe_intents?(payment_method)
      end
    end

    def paying_with_stripe_intents?
      return unless id = payments_attributes.first&.dig(:payment_method_id)

      stripe_intents?(Spree::PaymentMethod.find(id))
    end

    def stripe_intents?(payment_method)
      payment_method.respond_to?(:v3_intents?) && payment_method.v3_intents?
    end

    ::Spree::OrderUpdateAttributes.prepend(self)
  end
end
