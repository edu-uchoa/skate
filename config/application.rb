require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Skate
  # Intermediários em quem o Rails confia para achar o IP de quem usa o app: os de rede
  # interna (o padrão do Rails) e a Cloudflare, que fica na frente do Render. Usado em
  # config/environments/production.rb. Faixas oficiais em https://www.cloudflare.com/ips-v4
  # e https://www.cloudflare.com/ips-v6, conferidas em 2026-10-28 (mudam raramente).
  TRUSTED_PROXIES = (ActionDispatch::RemoteIp::TRUSTED_PROXIES + %w[
    173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18
    108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17
    162.158.0.0/15 104.16.0.0/13 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22
    2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32 2405:8100::/32
    2a06:98c0::/29 2c0f:f248::/32
  ].map { IPAddr.new(it) }).freeze

  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Sem as rotas públicas do Active Storage (/rails/active_storage/...): elas abriam
    # os vídeos dos treinos para qualquer pessoa com o link, sem login e sem expirar.
    # Os vídeos saem só por /videos/:id (ClipsController), com login e permissão.
    config.active_storage.draw_routes = false
  end
end
