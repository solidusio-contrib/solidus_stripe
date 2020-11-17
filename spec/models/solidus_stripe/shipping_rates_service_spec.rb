# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SolidusStripe::ShippingRatesService do
  let(:service) { described_class.new(order, user, params) }

  let(:order) { create :order }
  let(:user) { Spree::User.new }

  let(:params) do
    {
      country: Spree::ZoneMember.first.zoneable.iso,
      city: "Metropolis",
      postalCode: "12345",
      recipient: "",
      addressLine: []
    }
  end

  let(:ups_ground) { create(:shipping_method, cost: 5, available_to_all: false) }
  let(:air_mail) { create(:shipping_method, cost: 8, name: "Air Mail", available_to_all: false) }

  let(:fl_warehouse) { create(:stock_location, name: "FL Warehouse", shipping_methods: [ups_ground]) }
  let(:ca_warehouse) { create(:stock_location, name: "CA Warehouse", shipping_methods: [air_mail]) }

  before do
    create_list :inventory_unit, 2, order: order
    Spree::StockLocation.update_all backorderable_default: false
    Spree::StockItem.find_by(stock_location: fl_warehouse, variant: order.variants.first).set_count_on_hand(1)
    Spree::StockItem.find_by(stock_location: ca_warehouse, variant: order.variants.last).set_count_on_hand(1)
    order.create_proposed_shipments
  end

  describe "#call" do
    subject { service.call }

    context "when there are no common shipping methods for all order shipments" do
      it "cannot find any shipping rate" do
        expect(subject).to be_empty
      end
    end

    context "when there are common shipping methods for all order shipments" do
      before { fl_warehouse.shipping_methods << ca_warehouse.shipping_methods.first }

      context "when one shipping method is available for all shipments" do
        it "sums the shipping rates for the shared shipping method" do
          expect(subject).to eql [{ amount: 1600, id: air_mail.id.to_s, label: air_mail.name }]
        end
      end
    end
  end
end
