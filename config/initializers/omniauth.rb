# Entrar com o Google (GoogleSessionsController). O botão faz um POST para
# /auth/google_oauth2 (com o token CSRF, pela gem omniauth-rails_csrf_protection);
# o Google devolve a pessoa em /auth/google_oauth2/callback.
#
# Pedimos só o básico: e-mail e o identificador da conta (openid). Nome e foto do
# Google não são guardados: no app a pessoa aparece pelo nickname#0000 que escolhe.
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           Rails.configuration.x.flipaai.google_client_id,
           Rails.configuration.x.flipaai.google_client_secret,
           scope: "openid email",
           prompt: "select_account" # deixa escolher a conta, se houver mais de uma no aparelho
end

OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.logger = Rails.logger
# Qualquer erro do Google (a pessoa cancelou, a chave está errada...) volta para /auth/failure.
OmniAuth.config.on_failure = proc { |env| OmniAuth::FailureEndpoint.new(env).redirect_to_failure }
