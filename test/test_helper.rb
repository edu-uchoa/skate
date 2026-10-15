ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Testes em paralelo usam fork(), que não existe no Windows: lá rodam num processo só.
    parallelize(workers: Process.respond_to?(:fork) ? :number_of_processors : 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Metadados do vídeo lidos pelo ffprobe (vem junto com o ffmpeg): tags do
    # arquivo e de cada trilha, e a rotação.
    def video_metadata(path)
      probe = ::JSON.parse(IO.popen([ "ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", path.to_s ], &:read))
      {
        tags:     [ probe.dig("format", "tags"), *probe["streams"].map { |s| s["tags"] } ].compact.reduce({}, :merge),
        streams:  probe["streams"].map { |s| s["codec_type"] },
        rotation: probe["streams"].filter_map { |s| s["side_data_list"]&.find { |d| d.key?("rotation") }&.fetch("rotation") }.first
      }
    end

    # Tudo o que um vídeo limpo pode ter: nada que diga onde, quando ou com o quê foi gravado.
    CLEAN_VIDEO_TAGS = %w[major_brand minor_version compatible_brands language handler_name vendor_id].freeze
  end
end

# Entrar com o Google nos testes: o OmniAuth devolve uma resposta pronta, sem ir ao Google.
OmniAuth.config.test_mode = true
Rails.configuration.x.stance.google_client_id = "id-de-teste" # mostra o botão do Google nas telas

module GoogleSignIn
  # A volta do Google para essa conta. verified: false simula e-mail não confirmado.
  def google_auth(email, uid: "google-#{email.downcase}", verified: true)
    OmniAuth::AuthHash.new(provider: "google_oauth2", uid: uid,
                           info: { email: (email if verified), unverified_email: email, email_verified: verified })
  end

  # Toca em "Continuar com o Google" e volta do Google (a resposta fica em response).
  def sign_in_with_google(email, **options)
    OmniAuth.config.mock_auth[:google_oauth2] = google_auth(email, **options)
    post "/auth/google_oauth2"
    follow_redirect!
  end

  # Conta nova pelo Google, já com nickname: para os testes que só precisam de alguém logado.
  def sign_up_with_google(email, nickname: "skatista")
    sign_in_with_google(email)
    User.find_by!(email: email.strip.downcase).tap { |user| user.choose_nickname(nickname: nickname) }
  end
end

ActionDispatch::IntegrationTest.include(GoogleSignIn)
