# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SolidusStripe::PrepareOrderForPaymentService do
  let(:service) { described_class.new(address, controller) }

  let(:address) { create :address }
  let(:user) { double("Spree::User") }
  let(:email) { "foo@example.com" }
  let(:order) { create :order_with_line_items, state: :cart, ship_address: nil, bill_address: nil }
  let!(:shipping_method) { create :shipping_method, name: 'Air Mail', cost: 15 }
  let!(:other_shipping_method) { create :shipping_method, name: 'DHL', cost: 7 }
  let(:controller) do
    double(
      current_order: order,
      spree_current_user: user,
      params: {
        email: email,
        shipping_option: { id: shipping_method.id }
      }
    )
  end

  before do
    Spree::ZoneMember.create!(zone: Spree::Zone.first, zoneable: address.country)
  end

  describe "#call" do
    subject { service.call }

    it "sets the order ship and bill address" do
      expect { subject }.to change { order.ship_address }.to(address)
                                                         .and change { order.bill_address }.to(address)
    end

    context "when the user is not logged in" do
      let(:user) { nil }

      it "sets the order email to allow guest checkout" do
        expect { subject }.to change { order.email }.to(email)
      end
    end

    it "sets the right shipping rate" do
      expect { subject }.to change {
        order.shipments.first.selected_shipping_rate.shipping_method_id
      }.to(shipping_method.id)
    end

    context "when the order can be advanced to payment state" do
      it "advances the order to 'payment'" do
        expect { subject }.to change { order.state }.to("payment")
      end
    end

    context "when the order fails to be advanced to payment state" do
      before { order.line_items.destroy_all }

      it "leaves the order to a previous state" do
        expect { subject }.not_to change(order, :state)
      end
    end
  end
end
