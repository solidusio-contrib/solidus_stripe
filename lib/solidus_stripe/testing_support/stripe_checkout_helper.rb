# frozen_string_literal: true

module StripeCheckoutHelper
  def initialize_checkout
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
end
