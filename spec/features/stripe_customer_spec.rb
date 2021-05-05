# frozen_string_literal: true

require 'spec_helper'
require 'stripe'
Stripe.api_key = "sk_test_VCZnDv3GLU15TRvn8i2EsaAN"

RSpec.describe "Stripe checkout", type: :feature do
  let(:zone) { FactoryBot.create(:zone) }
  let(:country) { FactoryBot.create(:country) }

  before do
    initialize_checkout

    fill_in_card
    click_button "Save and Continue"

    # Confirmation
    expect(page).to have_current_path("/checkout/confirm")
    click_button "Place Order"
    expect(page).to have_content("Your order has been processed successfully")

    # Begin Second Purchase
    visit spree.root_path
    click_link "DL-44"
    click_button "Add To Cart"

    expect(page).to have_current_path("/cart")
    click_button "Checkout"

    # Address
    expect(page).to have_current_path("/checkout/address")

    within("#billing") do
      fill_in_name
      fill_in "Street Address", with: "YT-1300"
      fill_in "City", with: "Mos Eisley"
      select "United States of America", from: "Country"
      select country.states.first.name, from: "order_bill_address_attributes_state_id"
      fill_in "Zip", with: "12010"
      fill_in "Phone", with: "(555) 555-5555"
    end
    click_on "Save and Continue"

    # Delivery
    expect(page).to have_current_path("/checkout/delivery")
    expect(page).to have_content("UPS Ground")
    click_on "Save and Continue"

    # Payment
    expect(page).to have_current_path("/checkout/payment")
  end

  shared_examples "Maintain Consistent Stripe Customer Across Purchases" do
    it "can re-use saved cards and maintain the same Stripe payment ID and customer ID", js: true do

      choose "Use an existing card on file"
      click_button "Save and Continue"

      # Confirm
      expect(page).to have_current_path("/checkout/confirm")
      click_button "Place Order"
      expect(page).to have_content("Your order has been processed successfully")

      user = Spree::User.find_by_email("mary@example.com")
      user_sources = user.wallet.wallet_payment_sources
      expect(user_sources.size).to eq(1)

      user_card = user_sources.first.payment_source
      expect(user_card.gateway_customer_profile_id).to start_with 'cus_'
      expect(user_card.gateway_payment_profile_id).to start_with 'card_'

      stripe_customer = Stripe::Customer.retrieve(user_card.gateway_customer_profile_id)
      expect(stripe_customer[:email]).to eq(user.email)
      expect(stripe_customer[:sources][:total_count]).to eq(1)
      expect(stripe_customer[:sources][:data].first[:customer]).to eq(user_card.gateway_customer_profile_id)
      expect(stripe_customer[:sources][:data].first[:id]).to eq(user_card.gateway_payment_profile_id)

      expect(user.orders.map { |o| o.payments.valid.first.source.gateway_payment_profile_id }.uniq.size).to eq(1)
      expect(user.orders.map { |o| o.payments.valid.first.source.gateway_customer_profile_id }.uniq.size).to eq(1)
    end

    it "can use a new card and maintain the same Stripe customer ID", js: true do

      choose "Use a new card / payment method"
      fill_in_card({ number: '5555 5555 5555 4444' })
      click_button "Save and Continue"

      # Confirm
      expect(page).to have_current_path("/checkout/confirm")

      user = Spree::User.find_by_email("mary@example.com")
      user_cards = user.credit_cards
      expect(user_cards.size).to eq(2)
      expect(user_cards.pluck(:gateway_customer_profile_id)).to all( start_with 'cus_' )
      expect(user_cards.pluck(:gateway_payment_profile_id)).to all( start_with 'card_' )
      expect(user_cards.last.gateway_customer_profile_id).to eq(user_cards.first.gateway_customer_profile_id)
      expect(user_cards.pluck(:gateway_customer_profile_id).uniq.size).to eq(1)

      click_button "Place Order"
      expect(page).to have_content("Your order has been processed successfully")

      expect(user.wallet.wallet_payment_sources.size).to eq(2)
      expect(user.orders.map { |o| o.payments.valid.first.source.gateway_payment_profile_id }.uniq.size).to eq(2)
      expect(user.orders.map { |o| o.payments.valid.first.source.gateway_customer_profile_id }.uniq.size).to eq(1)

      stripe_customer = Stripe::Customer.retrieve(user_cards.last.gateway_customer_profile_id)
      stripe_customer_cards = Stripe::PaymentMethod.list({ customer: stripe_customer.id, type: 'card' })
      expect(stripe_customer_cards.count).to eq(2)
      expect(stripe_customer_cards.data.map { |card| card.id }).to match_array(user.orders.map { |o| o.payments.valid.first.source.gateway_payment_profile_id }.uniq)
      expect(stripe_customer_cards.data.map { |card| card.id }).to match_array(user_cards.pluck(:gateway_payment_profile_id))
    end
  end

  context 'when using Stripe V2 API library' do
    let(:preferred_v3_elements) { false }
    let(:preferred_v3_intents) { false }

    it_behaves_like "Maintain Consistent Stripe Customer Across Purchases"
  end

  context 'when using Stripe V3 API library with Elements' do
    let(:preferred_v3_elements) { true }
    let(:preferred_v3_intents) { false }

    it_behaves_like "Maintain Consistent Stripe Customer Across Purchases"
  end
end
