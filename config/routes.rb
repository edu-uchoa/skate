Rails.application.routes.draw do
  root "pages#landing"

  get  "abertura", to: "pages#intro",   as: :intro
  get  "instalar", to: "pages#install", as: :install

  namespace :onboarding, path: "comecar" do
    resource :age_gate,  only: %i[show update], path: "idade"
    resource :diagnosis, only: %i[show update], path: "diagnostico" do
      get :summary, on: :member, path: "plano"
    end
  end

  resource  :track,     only: :show, path: "trilha"
  resources :maneuvers, only: :show, path: "manobras", param: :slug do
    resources :training_sessions, only: %i[new create], path: "treinos", shallow: true
  end

  resources :training_sessions, only: %i[show update], path: "treinos" do
    member do
      patch :start
      get   :result,  path: "resultado"
      patch :submit,  path: "enviar"
    end
    resource :ai_review, only: :show, path: "devolutiva"
  end

  resources :schedules, only: %i[new create], path: "agenda"

  # Conta opcional (perfil temporário -> salvo) por código de acesso.
  resource  :account,      only: %i[new create], path: "salvar-progresso"
  resource  :access_code,  only: %i[new create],  path: "verificacao" do
    post :resend, on: :member, path: "reenviar"
  end
  delete "sair", to: "accounts#destroy", as: :sign_out

  resources :support_requests, only: %i[new create], path: "ajuda"
  resource  :comeback,         only: %i[new create], path: "retorno"

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "up" => "rails/health#show", as: :rails_health_check
end
