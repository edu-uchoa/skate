source "https://rubygems.org"


gem "rails", "~> 8.1"
gem "propshaft"
gem "sqlite3", ">= 2.1"           # troque por "pg" se for usar PostgreSQL
gem "puma", ">= 6.0"

# Front-end
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"

# Infra (Rails 8 defaults)
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false

# App
gem "bcrypt", "~> 3.1.7"          # digest dos códigos de acesso
gem "omniauth-google-oauth2"        # entrar com a conta Google
gem "omniauth-rails_csrf_protection" # o botão do Google só funciona por POST com token CSRF
gem "image_processing", "~> 1.2"  # previews dos vídeos (Active Storage)

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false
  gem "bundler-audit", require: false  # gems com falhas conhecidas (usado pelo CI)
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
gem "tzinfo-data"
gem "thor", "~> 1.3.2"
