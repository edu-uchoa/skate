require "test_helper"

# LGPD: Política de Privacidade e Termos públicos, aceite no cadastro, "Meus dados"
# (cópia em JSON) e "Apagar minha conta" pela própria pessoa.
class PrivacyTest < ActionDispatch::IntegrationTest
  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "0.3", slug: "t-queda",
                                 name: "QUEDA CONTROLADA", position: 0, kind: :drill)
  end

  def learner_with_history
    sign_up_with_google("dados@example.com", nickname: "Dados").tap do |user|
      user.update!(birth_year: 2005, terms_accepted_at: Time.current)
      session = user.training_sessions.new(maneuver: @maneuver, scheduled_on: Date.current, status: :submitted,
                                           submitted_at: Time.current, outcome: :felt_safe, notes: "Caí de lado",
                                           gear_checked: true, ground_clear: true, space_safe: true)
      session.clip.attach(io: File.open(file_fixture("manobra.mp4"), "rb"), filename: "manobra.mp4", content_type: "video/mp4")
      session.save!
      session.create_ai_review!(status: :pending)
      user.create_conversation!.messages.create!(author: user, body: "Oi, equipe!")
    end
  end

  test "a Política de Privacidade e os Termos abrem sem login e aparecem na tela da logo" do
    get root_path
    assert_select ".splash-legal a[href=?]", privacy_path
    assert_select ".splash-legal a[href=?]", terms_path

    get privacy_path
    assert_response :success
    assert_select "h2", "Política de Privacidade"
    assert_match Rails.configuration.x.flipaai.privacy_controller, response.body
    assert_select "a[href^='mailto:#{Rails.configuration.x.flipaai.privacy_email}']"

    get terms_path
    assert_response :success
    assert_select "h2", "Termos de Uso"
  end

  test "a tela da idade só segue com o aceite dos termos" do
    sign_in_with_google("nova@example.com")
    User.find_by!(email: "nova@example.com").choose_nickname(nickname: "nova")

    get onboarding_age_gate_path
    assert_select "input[type=checkbox][name=accept_terms][required]"
    assert_select ".legal-accept a[href=?]", privacy_path

    patch onboarding_age_gate_path, params: { user: { birth_year: 2000 } }
    assert_response :unprocessable_entity
    assert_nil User.find_by!(email: "nova@example.com").terms_accepted_at

    patch onboarding_age_gate_path, params: { user: { birth_year: 2000 }, accept_terms: "1" }
    assert_redirected_to onboarding_diagnosis_path
    assert User.find_by!(email: "nova@example.com").accepted_terms?
  end

  test "Meus dados baixa uma cópia sem os segredos da conta" do
    user = learner_with_history
    get my_account_path
    assert_select ".profile-privacy a[href=?]", my_data_path(format: :json)
    assert_select ".profile-privacy a[href=?]", account_deletion_path

    get my_data_path(format: :json)
    assert_response :success
    assert_match "attachment", response.headers["Content-Disposition"]
    data = JSON.parse(response.body)
    assert_equal "dados@example.com", data.dig("conta", "email")
    assert_equal user.handle, data.dig("conta", "nickname_completo")
    assert_equal "Caí de lado", data.dig("treinos_e_videos", 0, "anotacoes")
    assert_match %r{/videos/\d+}, data.dig("treinos_e_videos", 0, "video")
    assert_equal "Oi, equipe!", data.dig("chat", 0, "texto")
    [ user.token, "password_digest", "google_uid", user.google_uid ].each { |secret| assert_no_match secret, response.body }
  end

  test "apagar a conta exige digitar APAGAR e remove tudo" do
    user = learner_with_history
    video = user.training_sessions.first

    delete account_deletion_path, params: { confirmation: "sim" }
    assert_response :unprocessable_entity
    assert User.exists?(user.id)

    delete account_deletion_path, params: { confirmation: "apagar" }
    assert_redirected_to root_path
    assert_nil User.find_by(id: user.id)
    assert_nil TrainingSession.find_by(id: video.id)
    assert_equal 0, ActiveStorage::Attachment.where(record_type: "TrainingSession", record_id: video.id).count
    assert_equal 0, Conversation.where(learner_id: user.id).count

    get my_account_path
    assert_redirected_to root_path, "a sessão acabou junto"
  end

  test "sem login não dá para baixar nem apagar" do
    get my_data_path(format: :json)
    assert_redirected_to root_path
    delete account_deletion_path, params: { confirmation: "APAGAR" }
    assert_redirected_to root_path
  end
end
