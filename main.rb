require 'bundler/setup'
Bundler.require(:default)

require 'json'

# TODO: Do your magic 🧙‍♂️

filepath             = "car_infos.json"
serialized_car_infos = File.read(filepath)
car_infos            = JSON.parse(serialized_car_infos)

maiden_name   = car_infos["maiden_name"]
first_name    = car_infos["first_name"]
license_plate = car_infos["license_plate"]
formule_id    = car_infos["formule_id"]

BASE_HISTOVEC_SEARCH_URL = "https://histovec.interieur.gouv.fr/histovec/search"

ENV['VISIBLE_BROWSER'] ||= "true"

pivot_years_to_license_plate_button_titles_mapping = {
  before_1995: 'Immatriculation avant 1995',
  before_2009: 'Immatriculation avant 2009',
  since_2009:  'Immatriculation depuis 2009'
}

browser = Ferrum::Browser.new(
  headless:    ENV['VISIBLE_BROWSER'] == "false",
  window_size: [1358, 960]
)

# Début de la session de scrapping
browser.go_to(BASE_HISTOVEC_SEARCH_URL)

# Sélection du bon formulaire, en cliquant sur le "bon" bouton
license_plate_button_selector = "a[title='#{pivot_years_to_license_plate_button_titles_mapping[:since_2009]}']"
license_plate_button          = browser.at_css(license_plate_button_selector)

browser.mouse.scroll_to(*license_plate_button.find_position)
license_plate_button.click(delay: 3)

# Remplissage du formulaire affiché

# Il faudrait, dans une v10, variabiliser ces sélecteurs CSS en dur ici,
# pour les faire dépendre de la pivot_year de la plaque immat., comme le form
# n'est pas le même en fonction de l'année de la plaque immat

# pivot_years_to_license_plate_button_titles_mapping = {
#   before_1995: {
#     form_button_title: 'Immatriculation avant 1995',
#     form_fields: [
#       # ...
#     ]
#   }
#   before_2009: {
#     form_button_title: 'Immatriculation avant 2009',
#     form_fields: [
#       # ...
#     ]
#   }
#   since_2009:  {
#     form_button_title: 'Immatriculation depuis 2009',
#     form_fields: [
#       { selector: '[name="nom"]' },
#       { selector: '[id="firstname"]' },
#       { selector: '[id="plaque"]' },
#       { selector: '[id="formule"]', delay_for_each_letter: 0.5 }
#     ]
#   }
# }

# Pour notre v0, on ne choisira que des plaques immat > 2009 !

maiden_name_field   = browser.at_css('[name="nom"]')
first_name_field    = browser.at_css('[id="firstname"]')
license_plate_field = browser.at_css('[id="plaque"]')
formule_id_field    = browser.at_css('[id="formule"]')

maiden_name_field.focus.type(maiden_name)
first_name_field.focus.type(first_name)

browser.mouse.scroll_to(*license_plate_field.find_position)
license_plate_field.focus.type(license_plate)

letters = formule_id.split('')

letters.each do |letter|
  formule_id_field.focus.type(letter)
  sleep(0.5)
end


# Click sur le bouton search
search_button = browser.at_css('[class="btn btn-animated btn-default btn-sm btn-block"]')

browser.mouse.scroll_to(*search_button.find_position)
sleep(1)

search_button.click

sleep(3)

# Niveau critair
critair_selector = "//span[contains(text(), 'Eligible vignette Crit')]"
critair_span     = browser.at_xpath(critair_selector)
critair_level    = critair_span.text.gsub(" Eligible vignette Crit'Air", "").to_i

# Détails de la carte grise
car_registration_tab_button_selector = "//a[contains(text(), 'Titulaire & Titre')]"
car_registration_tab_button          = browser.at_xpath(car_registration_tab_button_selector)

browser.mouse.scroll_to(*car_registration_tab_button.find_position)
car_registration_tab_button.click

car_registration_tab_selector = "div.tab-pane.active"
car_registration_tab          = browser.at_css(car_registration_tab_selector)

sleep(2)

car_registration_first_license_plate_selector = "//h6[contains(text(), ' Carte grise ')]/following::div[1]/div[2]"
car_registration_first_license_plate_date     = browser.at_xpath(car_registration_first_license_plate_selector).text

current_car_registration_card_selector = "//h6[contains(text(), ' Carte grise ')]/following::div[5]/div[2]"
current_car_registration_card_date     = browser.at_xpath(current_car_registration_card_selector).text

# Historique des contrôles techniques
mot_history_button_selector = "//a[contains(text(), 'Contrôles techniques')]"
mot_history_button          = browser.at_xpath(mot_history_button_selector)

browser.mouse.scroll_to(*mot_history_button.find_position)
mot_history_button.click

mot_history_tab_selector = "div.tab-pane.active"
mot_history_tab          = browser.at_css(mot_history_tab_selector)

mot_history = mot_history_tab.xpath('div/div/div/div[@class = "row"]/div/span').
  each_slice(4).
  map do |slice|
    {
      date:        slice[0].text,
      description: slice[1].text,
      result:      slice[2].text,
      kms:         slice[3].text.gsub('km', '').gsub(',', '').strip.to_i,
    }
  end

out = {
  critair_level:                             critair_level,
  car_registration_first_license_plate_date: car_registration_first_license_plate_date,
  current_car_registration_card_date:        current_car_registration_card_date,
  mot_history:                               mot_history
}

binding.pry
browser.quit
