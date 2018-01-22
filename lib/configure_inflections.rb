require 'active_support/inflector'

# Custom rules for pluralizing and singularizing nouns
# see http://api.rubyonrails.org/classes/ActiveSupport/Inflector/Inflections.html
ActiveSupport::Inflector.inflections do |inflect|
  inflect.irregular 'lotus', 'lotuses'
  inflect.irregular 'clothes', 'clothes'
end