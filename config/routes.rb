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

  # Funcionalidades Front-end
  resource  :store,  only: :show, path: "loja"
  resource  :avatar, only: :show, path: "avatar"
  resource  :deck,   only: :show, path: "deck"
  resources :spots,  only: :index, path: "picos"

  # Conta obrigatória: cadastro/login com e-mail ou telefone e senha.
  resource  :account,        only: %i[new create], path: "cadastro", path_names: { new: "" }
  resource  :session,        only: %i[new create], path: "entrar", path_names: { new: "" }
  resource  :password_reset, only: %i[new create edit update], path: "recuperar-senha",
                             path_names: { new: "", edit: "nova-senha" } do
    post :resend, on: :member, path: "reenviar"
  end
  get    "conta", to: "accounts#show",        as: :my_account
  delete "sair",  to: "accounts#destroy",     as: :sign_out
  delete "sair-de-todos", to: "accounts#destroy_all", as: :sign_out_everywhere

  resources :support_requests, only: %i[new create], path: "ajuda"
  resource  :comeback,         only: %i[new create], path: "retorno"

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "up" => "rails/health#show", as: :rails_health_check
end
