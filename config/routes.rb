Rails.application.routes.draw do
  root "pages#landing"

  get  "abertura", to: "pages#intro",   as: :intro
  get  "instalar", to: "pages#install", as: :install
  # LGPD: textos públicos (dá para ler antes de entrar).
  get  "privacidade", to: "pages#privacy", as: :privacy
  get  "termos",      to: "pages#terms",   as: :terms

  namespace :onboarding, path: "comecar" do
    resource :age_gate,  only: %i[show update], path: "idade"
    resource :diagnosis, only: %i[show update], path: "diagnostico" do
      get :summary, on: :member, path: "plano"
    end
  end

  resource  :track,     only: :show, path: "trilha"
  resources :maneuvers, only: :show, path: "manobras", param: :slug do
    post :skip, on: :member, path: "avancar" # "Avançar para a próxima tarefa"
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
  resource  :recording, only: %i[new create], path: "gravar", path_names: { new: "" } do
    get :sending, path: "envio" # vídeos guardados no aparelho esperando envio
  end
  resource  :zine,      only: :show, path: "zine"

  # Vídeos dos treinos, só com login e permissão (ClipsController).
  resources :clips, only: %i[show destroy], path: "videos"

  # Pedido para ser mentor (feito no cadastro ou em "Minha conta").
  resource :mentor_application, only: %i[new create], path: "quero-ser-mentor", path_names: { new: "" }

  # Área do mentor: mentores aprovados por um administrador, e administradores.
  namespace :mentor do
    resource  :zine,     only: :show, path: "zine"
    resources :requests, only: %i[index update destroy], path: "pedidos"   # só administrador
    resources :mentors,  only: :destroy, path: "mentores"                   # só administrador
    # Devolutiva escrita no cartão do vídeo: enviar (fila) e revisar (todos).
    resources :videos,   only: [], path: "videos" do
      resource :review,  only: %i[create update], path: "devolutiva"
    end
    resources :streak_justifications, only: %i[index update], path: "ofensivas" # paradas para avaliar
    # Chat com cada aprendiz (a conversa é da equipe de mentores).
    resources :chats,    only: %i[index show], path: "chat" do
      resources :messages, only: :create, path: "mensagens"
    end
  end

  # Painel do super administrador (o dono do app): contas, vídeos e devolutivas. Só
  # entra a conta Google com e-mail em SUPER_ADMIN_EMAILS; para os outros é 404.
  namespace :admin, path: "painel" do
    root "dashboards#show"
    resources :users,   only: %i[index destroy], path: "usuarios" do
      patch :demote, on: :member, path: "tirar-acesso" # mentor ou administrador volta a aprendiz
    end
    resources :videos,  only: %i[index destroy]
    resources :reviews, only: %i[index destroy], path: "devolutivas"
  end

  # Chat do aprendiz com a equipe de mentores.
  resource :chat, only: :show, path: "chat" do
    resources :messages, only: :create, path: "mensagens"
  end

  # Todas as tarefas da trilha: as concluídas e as que faltam (botão do Perfil).
  resources :tasks, only: :index, path: "tarefas"

  # Ofensiva por sessão de skate: como funciona e justificativa de parada.
  resource  :streak, only: :show, path: "ofensiva"
  resources :streak_justifications, only: :create, path: "ofensiva/justificativas"

  # Mapa de Picos (Google Maps): picos fixos e os rolês que a pessoa marca.
  resources :spots,   only: :index, path: "picos"
  resources :meetups, only: %i[create destroy], path: "roles"
  get "role/:token", to: "shared_meetups#show", as: :shared_meetup # link público para os amigos

  # Perfil (/conta): o avatar de skatista e o skate que a pessoa personaliza.
  resource  :avatar, only: :update, path: "conta/avatar"
  resource  :deck,   only: :update, path: "conta/skate"

  # Funcionalidades Front-end
  resource  :store,  only: :show, path: "loja"

  # Conta obrigatória: entrar com o Google pela tela da logo (/). Os botões fazem POST
  # /auth/google_oauth2, que o OmniAuth leva ao Google. As telas antigas de cadastro e
  # de login voltam para a logo.
  get "cadastro", to: redirect("/")
  get "entrar",   to: redirect("/")
  # Login com senha das contas antigas (mentores e administradores, até a versão web
  # deles): /entrar/senha, sem link no app.
  resource :session,        only: %i[new create], path: "entrar", path_names: { new: "senha" }
  get "auth/google_oauth2/callback", to: "google_sessions#create", as: :google_callback
  get "auth/failure",                to: "google_sessions#failure", as: :google_failure
  resource  :nickname,       only: %i[edit update], path: "apelido", path_names: { edit: "" }
  resource  :password_reset, only: %i[new create edit update], path: "recuperar-senha",
                             path_names: { new: "", edit: "nova-senha" } do
    post :resend, on: :member, path: "reenviar"
  end
  get    "conta", to: "accounts#show",        as: :my_account
  # LGPD (art. 18): baixar uma cópia dos próprios dados e apagar a conta sozinho.
  get    "conta/meus-dados", to: "data_exports#show", as: :my_data, defaults: { format: :json }
  resource :account_deletion, only: %i[show destroy], path: "conta/apagar"
  delete "sair",  to: "accounts#destroy",     as: :sign_out
  delete "sair-de-todos", to: "accounts#destroy_all", as: :sign_out_everywhere

  resources :support_requests, only: %i[new create], path: "ajuda"
  resource  :comeback,         only: %i[new create], path: "retorno"

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "up" => "rails/health#show", as: :rails_health_check
end
