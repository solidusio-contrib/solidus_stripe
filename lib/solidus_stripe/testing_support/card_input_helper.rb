# frozen_string_literal: true

module SolidusCardInputHelper
  def fill_in_card(card = {})
    card[:number] ||= "4242 4242 4242 4242"
    card[:code] ||= "123"
    card[:exp_month] ||= "01"
    card[:exp_year] ||= (Time.zone.now.year + 1).to_s

    if preferred_v3_elements || preferred_v3_intents
      within_frame find('#card_number iframe') do
        card[:number].split('').each { |n| find_field('cardnumber').native.send_keys(n) }
      end
      within_frame(find('#card_cvc iframe')) { fill_in 'cvc', with: card[:code] }
      within_frame(find('#card_expiry iframe')) do
        "#{card[:exp_month]}#{card[:exp_year].last(2)}".split('')
                                                       .each { |n| find_field('exp-date').native.send_keys(n) }
      end
    else
      fill_in "Card Number", with: card[:number]
      fill_in "Card Code", with: card[:code]
      fill_in "Expiration", with: "#{card[:exp_month]} / #{card[:exp_year]}"
    end
  end
end
