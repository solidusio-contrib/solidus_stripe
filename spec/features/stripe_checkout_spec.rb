# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Stripe checkout", type: :feature do
  let(:zone) { FactoryBot.create(:zone) }
  let(:country) { FactoryBot.create(:country) }

  let(:card_3d_secure) { "4000 0025 0000 3155" }

  before do
    FactoryBot.create(:store)
    zone.members << Spree::ZoneMember.create!(zoneable: country)
    FactoryBot.create(:free_shipping_method)

    Spree::PaymentMethod::StripeCreditCard.create!(
      name: "Stripe",
      preferred_secret_key: "sk_test_VCZnDv3GLU15TRvn8i2EsaAN",
      preferred_publishable_key: "pk_test_Cuf0PNtiAkkMpTVC2gwYDMIg",
      preferred_v3_elements: preferred_v3_elements,
      preferred_v3_intents: preferred_v3_intents
    )

    FactoryBot.create(:product, name: "DL-44")

    visit spree.root_path
    click_link "DL-44"
    click_button "Add To Cart"

    expect(page).to have_current_path("/cart")
    click_button "Checkout"

    expect(page).to have_current_path("/checkout/registration")
    click_link "Create a new account"
    within("#new_spree_user") do
      fill_in "Email", with: "mary@example.com"
      fill_in "Password", with: "superStrongPassword"
      fill_in "Password Confirmation", with: "superStrongPassword"
    end
    click_button "Create"

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

  # This will fetch a token from Stripe.com and then pass that to the webserver.
  # The server then processes the payment using that token.

  context 'when using Stripe V2 API library' do
    let(:preferred_v3_elements) { false }
    let(:preferred_v3_intents) { false }

    it "can process a valid payment", js: true do
      fill_in_card
      click_button "Save and Continue"
      expect(page).to have_current_path("/checkout/confirm")
      click_button "Place Order"
      expect(page).to have_content("Your order has been processed successfully")
    end

    it "can re-use saved cards", js: true do
      fill_in_card
      click_button "Save and Continue"

      expect(page).to have_current_path("/checkout/confirm")
      click_button "Place Order"
      expect(page).to have_content("Your order has been processed successfully")

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
      choose "Use an existing card on file"
      click_button "Save and Continue"

      # Confirm
      expect(page).to have_current_path("/checkout/confirm")
      click_button "Place Order"
      expect(page).to have_content("Your order has been processed successfully")
    end

    it "shows an error with a missing credit card number", js: true do
      fill_in_card({ number: "", code: "" })
      click_button "Save and Continue"
      expect(page).to have_content("Could not find payment information")
    end

    it "shows an error with a missing expiration date", js: true do
      fill_in_card({ exp_month: "", exp_year: "" })
      click_button "Save and Continue"
      expect(page).to have_content("Your card's expiration year is invalid.")
    end

    it "shows an error with an invalid credit card number", js: true do
      fill_in_card({ number: "1111 1111 1111 1111" })
      click_button "Save and Continue"
      expect(page).to have_content("Your card number is incorrect.")
    end

    it "shows an error with invalid security fields", js: true do
      fill_in_card({ code: "12" })
      click_button "Save and Continue"
      expect(page).to have_content("Your card's security code is invalid.")
    end

    it "shows an error with invalid expiry fields", js: true do
      fill_in_card({ exp_month: "00" })
      click_button "Save and Continue"
      expect(page).to have_content("Your card's expiration month is invalid.")
    end
  end

  shared_examples "Stripe Elements invalid payments" do
    it "shows an error with a missing credit card number" do
      fill_in_card({ number: "" })
      click_button "Save and Continue"
      expect(page).to have_content("Your card number is incomplete.")
    end

    it "shows an error with a missing expiration date" do
      fill_in_card({ exp_month: "", exp_year: "" })
      click_button "Save and Continue"
      expect(page).to have_content("Your card's expiration date is incomplete.")
    end

    it "shows an error with an invalid credit card number" do
      fill_in_card({ number: "1111 1111 1111 1111" })
      click_button "Save and Continue"
      expect(page).to have_content("Your card number is invalid.")
    end

    it "shows an error with invalid security fields" do
      fill_in_card({ code: "12" })
      click_button "Save and Continue"
      expect(page).to have_content("Your card's security code is incomplete.")
    end

    it "shows an error with invalid expiry fields" do
      fill_in_card({ exp_month: "01", exp_year: "3" })
      click_button "Save and Continue"
      expect(page).to have_content("Your card's expiration date is incomplete.")
    end
  end

  context 'when using Stripe V3 API library with Elements', :js do
    let(:preferred_v3_elements) { true }
    let(:preferred_v3_intents) { false }

    it "can process a valid payment" do
      fill_in_card
      click_button "Save and Continue"
      expect(page).to have_current_path("/checkout/confirm")
      click_button "Place Order"
      expect(page).to have_content("Your order has been processed successfully")
    end

    context "when reusing saved cards" do
      stub_authorization!

      it "completes the order, captures the payment and cancels the order" do
        fill_in_card
        click_button "Save and Continue"
        expect(page).to have_current_path("/checkout/confirm")
        click_button "Place Order"
        expect(page).to have_content("Your order has been processed successfully")

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
        choose "Use an existing card on file"
        click_button "Save and Continue"

        # Confirm
        expect(page).to have_current_path("/checkout/confirm")
        click_button "Place Order"
        expect(page).to have_content("Your order has been processed successfully")

        Spree::Order.complete.each do |order|
          # Capture in backend

          visit spree.admin_path

          expect(page).to have_selector("#listing_orders tbody tr", count: 2)

          click_link order.number

          click_link "Payments"
          find(".fa-capture").click

          expect(page).to have_content "Payment Updated"
          expect(find("table#payments")).to have_content "Completed"

          # Order cancel, after capture
          click_link "Cart"

          within "#sidebar" do
            expect(page).to have_content "Completed"
          end

          page.accept_alert do
            find('input[value="Cancel"]').click
          end

          expect(page).to have_content "Order canceled"

          within "#sidebar" do
            expect(page).to have_content "Canceled"
          end
        end
      end
    end

    it_behaves_like "Stripe Elements invalid payments"
  end

  context "when using Stripe V3 API library with Intents", :js do
    let(:preferred_v3_elements) { false }
    let(:preferred_v3_intents) { true }

    context "when using a valid 3D Secure card" do
      it "successfully completes the checkout" do
        authenticate_3d_secure_card(card_3d_secure)

        expect(page).to have_current_path("/checkout/confirm")

        click_button "Place Order"

        expect(page).to have_content("Your order has been processed successfully")
      end
    end

    context "when using a card without enough money" do
      it "fails the payment" do
        fill_in_card({ number: "4000 0000 0000 9995" })
        click_button "Save and Continue"

        expect(page).to have_content "Your card has insufficient funds."
      end
    end

    context "when entering the wrong 3D verification code" do
      it "fails the payment" do
        fill_in_card({ number: "4000 0084 0000 1629" })
        click_button "Save and Continue"

        within_3d_secure_modal do
          click_button 'Complete authentication'
        end

        expect(page).to have_content "Your card was declined."
      end
    end

    context "when reusing a card" do
      stub_authorization!

      it "succesfully creates a second payment that can be captured in the backend" do
        authenticate_3d_secure_card(card_3d_secure)

        expect(page).to have_current_path("/checkout/confirm")
        click_button "Place Order"
        expect(page).to have_content("Your order has been processed successfully")

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
        choose "Use an existing card on file"
        click_button "Save and Continue"

        # Confirm
        expect(page).to have_current_path("/checkout/confirm")
        click_button "Place Order"
        expect(page).to have_content("Your order has been processed successfully")

        Spree::Order.complete.each do |order|
          # Capture in backend

          visit spree.admin_path

          expect(page).to have_selector("#listing_orders tbody tr", count: 2)

          click_link order.number

          click_link "Payments"
          find(".fa-capture").click

          expect(page).to have_content "Payment Updated"
          expect(find("table#payments")).to have_content "Completed"

          # Order cancel, after capture
          click_link "Cart"

          within "#sidebar" do
            expect(page).to have_content "Completed"
          end

          page.accept_alert do
            find('input[value="Cancel"]').click
          end

          expect(page).to have_content "Order canceled"

          within "#sidebar" do
            expect(page).to have_content "Canceled"
          end
        end
      end
    end

    context "when paying with multiple payment methods" do
      stub_authorization!

      context "when paying first with regular card, then with 3D-Secure card" do
        let(:regular_card) { "4242 4242 4242 4242" }

        it "voids the first stripe payment and successfully pays with 3DS card" do
          fill_in_card({ number: regular_card })
          click_button "Save and Continue"

          expect(page).to have_content "Ending in #{regular_card.last(4)}"

          click_link "Payment"

          authenticate_3d_secure_card(card_3d_secure)
          click_button "Place Order"
          expect(page).to have_content "Your order has been processed successfully"

          visit spree.admin_path
          click_link Spree::Order.complete.first.number
          click_link "Payments"

          payments = all('table#payments tbody tr')

          expect(payments.first).to have_content "Stripe"
          expect(payments.first).to have_content "Void"

          expect(payments.last).to have_content "Stripe"
          expect(payments.last).to have_content "Pending"
        end
      end

      context "when paying first with 3D-Secure card, then with check" do
        before { create :check_payment_method }

        it "voids the stripe payment and successfully pays with check" do
          authenticate_3d_secure_card(card_3d_secure)
          expect(page).to have_current_path("/checkout/confirm")

          click_link "Payment"
          choose "Check"
          click_button "Save and Continue"
          expect(find(".payment-info")).to have_content "Check"
          expect(page).to have_content "Your order has been processed successfully"

          visit spree.admin_path
          click_link Spree::Order.complete.first.number
          click_link "Payments"
          payments = all('table#payments tbody tr')

          stripe_payment = payments.first
          expect(stripe_payment).to have_content "Stripe"
          expect(stripe_payment).to have_content "Void"

          check_payment = payments.last
          expect(check_payment).to have_content "Check"
        end
      end
    end

    it_behaves_like "Stripe Elements invalid payments"
  end

  def within_3d_secure_modal(&block)
    within_frame find("iframe[src*='authorize-with-url-inner']") do
      within_frame "__stripeJSChallengeFrame" do
        within_frame "acsFrame", &block
      end
    end
  end

  def authenticate_3d_secure_card(card_number)
    fill_in_card({ number: card_number })
    click_button "Save and Continue"

    within_3d_secure_modal do
      expect(page).to have_content '$19.99 USD using 3D Secure'

      click_button 'Complete authentication'
    end
  end
end
