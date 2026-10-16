require "test_helper"

class GoogleLoginTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  def choose(nickname, tag: "") = patch(nickname_path, params: { nickname: { nickname: nickname, tag: tag } })

  test "conta nova pelo Google escolhe o nickname#0000 antes de usar o app" do
    sign_in_with_google("Nova@Example.com")
    assert_redirected_to edit_nickname_path
    user = User.find_by!(email: "nova@example.com")
    assert user.google?
    assert_nil user.password_digest
    assert user.role_learner?

    get track_path
    assert_redirected_to edit_nickname_path, "sem nickname o app não abre"

    get edit_nickname_path
    assert_select "h2", "Escolha seu nickname"
    assert_select "input[name='nickname[tag]'][placeholder]"

    choose "Rato.de_Pista-01"
    assert_redirected_to onboarding_age_gate_path
    user.reload
    assert_equal "Rato.de_Pista-01", user.nickname
    assert_match(/\A\d{4}\z/, user.nickname_tag)
    assert_not_equal "0000", user.nickname_tag

    get my_account_path
    assert_select ".profile-handle", user.handle
    get track_path
    assert_redirected_to onboarding_age_gate_path, "com nickname, segue o onboarding normal"
  end

  test "quem volta pelo Google cai na mesma conta, com o histórico" do
    user = sign_up_with_google("volta@example.com")
    user.update!(birth_year: 2001, terms_accepted_at: Time.current)
    delete sign_out_path

    get my_account_path
    sign_in_with_google("volta@example.com")
    assert_redirected_to my_account_path, "volta para onde a pessoa queria ir"
    assert_equal 1, User.where(email: "volta@example.com").count
    assert_equal 2001, User.find_by(email: "volta@example.com").birth_year
  end

  test "o Google só aceita POST com token: um link GET não inicia o login" do
    get "/auth/google_oauth2"
    assert_response :not_found
  end

  test "e-mail não confirmado no Google não entra nem cria conta" do
    sign_in_with_google("sem.confirmar@example.com", verified: false)
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match "e-mail confirmado", response.body
    assert_equal 0, User.count
  end

  test "Google cancelado volta para o login com aviso" do
    OmniAuth.config.mock_auth[:google_oauth2] = :access_denied
    post "/auth/google_oauth2"
    follow_redirect! # volta do Google
    follow_redirect! # /auth/failure
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match "Não deu para entrar com o Google", response.body
  ensure
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  test "conta antiga com o mesmo e-mail vira conta Google sem perder nada" do
    old = User.register(contact: "antiga@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    old.update!(birth_year: 1999, terms_accepted_at: Time.current)
    old_token = old.token

    sign_in_with_google("ANTIGA@example.com")
    assert_redirected_to edit_nickname_path
    old.reload
    assert_equal "google-antiga@example.com", old.google_uid
    assert_equal 1999, old.birth_year
    assert_equal 1, User.count
    assert_nil old.password_digest, "a senha antiga deixa de valer"
    assert_not_equal old_token, old.token, "outras sessões abertas com a senha caem"

    delete sign_out_path
    post session_path, params: { session: { contact: "antiga@example.com", password: PASSWORD } }
    assert_response :unprocessable_entity
  end

  test "conta antiga com telefone liga o Google pelo Perfil" do
    old = User.register(contact: "61999990000", password: PASSWORD, password_confirmation: PASSWORD)
    old.update!(birth_year: 1998, terms_accepted_at: Time.current)
    post session_path, params: { session: { contact: "61999990000", password: PASSWORD } }

    get my_account_path
    assert_select "form[action='/auth/google_oauth2']"
    sign_in_with_google("telefone@example.com")
    assert_redirected_to edit_nickname_path
    old.reload
    assert old.google?
    assert_equal 1998, old.birth_year
    assert_equal 1, User.count

    choose "telefone"
    assert_redirected_to onboarding_age_gate_path
    delete sign_out_path
    sign_in_with_google("telefone@example.com")
    assert_redirected_to track_path
    assert_equal old, User.find_by(google_uid: "google-telefone@example.com")
  end

  test "uma conta Google não pode ser ligada a duas contas do FlipaAi" do
    sign_up_with_google("dono@example.com")
    delete sign_out_path

    User.register(contact: "outra@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    post session_path, params: { session: { contact: "outra@example.com", password: PASSWORD } }
    sign_in_with_google("dono@example.com")
    assert_redirected_to my_account_path
    follow_redirect!
    assert_match "já está ligada a outra conta", response.body
    assert_not User.find_by(email: "outra@example.com").google?
  end

  test "nickname igual é aceito com outro número, mas o mesmo nickname#0000 não" do
    sign_up_with_google("primeira@example.com").update!(nickname: "Skatista", nickname_tag: "0420")
    delete sign_out_path

    sign_in_with_google("segunda@example.com")
    choose "skatista", tag: "0420"
    assert_response :unprocessable_entity
    assert_match "skatista#0420 já existe", response.body

    choose "skatista", tag: "#0421"
    assert_redirected_to onboarding_age_gate_path
    assert_equal "skatista#0421", User.find_by(email: "segunda@example.com").handle
    assert_equal 2, User.where(nickname_key: "skatista").count
  end

  test "nickname precisa ser curto, sem espaço e sem parecer telefone" do
    sign_in_with_google("regras@example.com")

    { "ab"             => "de 3 a 20 caracteres",
      "nome sobrenome" => "sem espaço",
      "61999990000"    => "parecer um telefone" }.each do |nickname, message|
      choose nickname
      assert_response :unprocessable_entity
      assert_match message, response.body
    end

    choose "nick@legal"
    assert_match "sem espaço", response.body

    choose "valido", tag: "0000"
    assert_match "de 0001 a 9999", response.body
    assert_nil User.find_by(email: "regras@example.com").handle
  end

  test "trocar o nickname mantém o número quando o nome é o mesmo" do
    user = sign_up_with_google("troca@example.com", nickname: "lento")
    tag = user.nickname_tag

    get edit_nickname_path
    assert_select "h2", "Trocar o nickname"
    choose "LENTO"
    assert_redirected_to my_account_path
    assert_equal "LENTO##{tag}", user.reload.handle
  end

  test "o mentor vê o nickname#0000, não o e-mail" do
    learner = sign_up_with_google("aluno@example.com", nickname: "aluno")
    learner.update!(birth_year: 2000, terms_accepted_at: Time.current)
    post chat_messages_path, params: { message: { body: "Oi, equipe!" } }, as: :turbo_stream
    delete sign_out_path

    mentor = User.register(contact: "mentor@example.com", password: PASSWORD, password_confirmation: PASSWORD).tap(&:role_mentor!)
    post session_path, params: { session: { contact: mentor.contact, password: PASSWORD } }
    get mentor_chats_path
    assert_select "a.chat-list-item strong", /#{Regexp.escape(learner.handle)}/
    assert_no_match "aluno@example.com", response.body
  end
end
