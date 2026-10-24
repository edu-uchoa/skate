require "test_helper"

# O aprendiz escolhe o mentor que avalia o vídeo (tela Gravar) e, na devolutiva, dá de
# 1 a 10 rolamentos ao mentor. A média de cada mentor aparece na hora da escolha.
class MentorChoiceTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"
  ANSWER = { headline: "Mandou bem!", strengths: "Joelhos dobrados.", mistake: "Braço esticado.",
             next_focus: "Role pelo ombro." }.freeze

  setup do
    @original_emails = Rails.configuration.x.flipaai.super_admin_emails
    Rails.configuration.x.flipaai.super_admin_emails = [ "dono@example.com" ]

    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "0.3", slug: "t-queda",
                                 name: "QUEDA CONTROLADA", position: 0, kind: :drill)
    @learner = account("aprendiz@example.com", nickname: "Rato")
    @learner.create_diagnosis!(level: :never_ridden, setup: :store_board, completed_at: Time.current)
    @ana  = account("ana@example.com", nickname: "Ana", role: :mentor)
    @ana.update!(mentor_bio: "Ando há 12 anos e dou aula de street para quem está começando.")
    @beto = account("beto@example.com", nickname: "Beto", role: :admin)
    # O dono do app (super admin), mesmo com papel de administrador, não entra na lista.
    @owner = account("dono@example.com", nickname: "Dono", role: :admin)
    @owner.update!(google_uid: "google-dono")
  end

  teardown { Rails.configuration.x.flipaai.super_admin_emails = @original_emails }

  def account(contact, nickname:, role: :learner)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      user.update!(birth_year: 1995, terms_accepted_at: Time.current, role: role)
      user.choose_nickname(nickname: nickname)
    end
  end

  def sign_in(user)
    delete sign_out_path # troca de conta no meio do teste
    post session_path, params: { session: { contact: user.contact, password: PASSWORD } }
  end
  def card(session) = "#" + ActionView::RecordIdentifier.dom_id(session, :mentor)

  def clip_for(user, mentor: nil)
    session = user.training_sessions.new(maneuver: @maneuver, scheduled_on: Date.current, status: :in_progress,
                                         gear_checked: true, ground_clear: true, space_safe: true, mentor: mentor)
    session.clip.attach(io: File.open(file_fixture("manobra.mp4"), "rb"), filename: "manobra.mp4", content_type: "video/mp4")
    session.save!
    session
  end

  # Devolutiva já escrita pelo mentor e avaliada pelo aprendiz com a nota dada.
  def rated_review(learner, mentor, rating)
    review = clip_for(learner, mentor: mentor).create_ai_review!(status: :pending)
    review.answer(mentor, **ANSWER)
    review.rate(rating)
    review
  end

  test "a tela Gravar lista os mentores (menos o super admin), com o resumo e a média, do mais bem avaliado" do
    other = account("outro@example.com", nickname: "Outro")
    rated_review(@learner, @beto, 9)
    rated_review(other, @beto, 8)

    sign_in(@learner)
    get new_recording_path
    assert_response :success

    names = css_select(".mentor-picker .mentor-name").map { |name| name.text.strip }
    assert_equal [ "Beto##{@beto.nickname_tag}", "Ana##{@ana.nickname_tag}" ], names, "Beto (avaliado) antes da Ana"
    assert_select ".mentor-picker" do
      assert_select "input[type=radio][name='recording[mentor_id]'][data-recorder-target=mentor]", 2
      assert_select ".mentor-bio", /dou aula de street/
      assert_select ".mentor-score", /8,5\s*· 2 alunos avaliaram/
      assert_select ".mentor-score", /Sem avaliações ainda/
      assert_select ".mentor-name", text: /Dono/, count: 0
    end
  end

  test "mentor sem nickname não entra na lista e o Perfil dele avisa" do
    nameless = User.register(contact: "sem-nick@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    nameless.update!(birth_year: 1990, role: :mentor)

    sign_in(@learner)
    get new_recording_path
    assert_select ".mentor-name", text: /Mentor #/, count: 0
    assert_equal [ @ana, @beto ].sort_by(&:id), User.available_mentors.sort_by(&:id)

    sign_in(nameless)
    get my_account_path
    assert_select "#mentor .zine-status.warn", /Escolha um nickname/
    assert_select "#mentor a[href=?]", edit_nickname_path
  end

  test "o vídeo vai para o mentor escolhido; quem não está na lista vira qualquer mentor" do
    sign_in(@learner)
    send_clip = lambda do |mentor_id|
      post recording_path, headers: { "Accept" => "application/json" },
                           params: { recording: { clip: fixture_file_upload("manobra.mp4", "video/mp4", true), maneuver_slug: @maneuver.slug,
                                                  gear_checked: "1", ground_clear: "1", space_safe: "1", mentor_id: mentor_id } }
      assert_response :created
      TrainingSession.last.mentor
    end

    assert_equal @ana, send_clip.(@ana.id)
    assert_nil send_clip.(@owner.id), "super admin não é escolhido"
    assert_nil send_clip.(@learner.id), "aprendiz não é mentor"
    assert_nil send_clip.("")

    get new_recording_path
    assert_select "input[name='recording[mentor_id]'][value='#{@ana.id}'][checked]", 1, "já vem marcado o último escolhido"
  end

  test "só o escolhido vê e responde o vídeo; depois de 48h sem resposta, qualquer mentor" do
    session = clip_for(@learner, mentor: @ana)

    sign_in(@beto)
    get mentor_zine_path
    assert_select card(session), 0, "fora da fila do Beto"
    post mentor_video_review_path(session), params: { review: ANSWER }
    assert_redirected_to mentor_zine_path(aba: "todos", anchor: card(session).delete_prefix("#"))
    assert_nil session.reload.ai_review, "o Beto não responde antes do prazo"

    get mentor_zine_path(aba: "todos")
    assert_select card(session) do
      assert_select ".zine-status.warn", /Escolheu Ana.*Sem resposta em 48h, o vídeo vai para a sua fila/m
      assert_select "a.review-go", 0
    end

    sign_in(@ana)
    get mentor_zine_path
    assert_select ".mentor-nav .nav-fab-btn .nav-badge", "1"
    assert_select card(session) do
      assert_select ".zine-status.ok", /escolheu você/
      assert_select "form.review-form"
    end

    travel 49.hours do
      sign_in(@beto)
      get mentor_zine_path
      assert_select card(session) { assert_select ".zine-status.warn", /sem resposta em 48h: qualquer mentor pode responder/ }
      post mentor_video_review_path(session), params: { review: ANSWER }
      assert_equal @beto, session.reload.ai_review.reviewer
    end
  end

  test "a devolutiva traz o nome e a média do mentor, e o aprendiz avalia uma vez, se quiser" do
    rated_review(account("outro@example.com", nickname: "Outro"), @ana, 6)
    session = clip_for(@learner, mentor: @ana)
    session.create_ai_review!(status: :pending).answer(@ana, **ANSWER)

    sign_in(@learner)
    get training_session_ai_review_path(session)
    assert_select ".review-mentor" do
      assert_select ".mentor-name", "Ana##{@ana.nickname_tag}"
      assert_select ".mentor-score", /6,0\s*· 1 aluno avaliou/
    end
    assert_select "form.review-rating-form[action=?]", training_session_ai_review_rating_path(session) do
      assert_select "input[type=radio][name='rating[value]'][required]", 10
      assert_select "textarea[name='rating[comment]']:not([required])"
    end

    post training_session_ai_review_rating_path(session), params: { rating: { value: "11" } }
    assert_response :unprocessable_entity
    assert_match "Escolha de 1 a 10 rolamentos.", response.body

    post training_session_ai_review_rating_path(session), params: { rating: { value: "8", comment: "me chama no @rato.skate" } }
    assert_response :unprocessable_entity
    assert_match "não mande telefone, e-mail, links ou @", response.body
    assert_select "textarea[name='rating[comment]']", "me chama no @rato.skate"

    post training_session_ai_review_rating_path(session), params: { rating: { value: "8", comment: "Explicou bem onde eu errei." } }
    assert_redirected_to training_session_ai_review_path(session, anchor: "avaliar")
    review = session.reload.ai_review
    assert_equal [ 8, "Explicou bem onde eu errei." ], [ review.rating, review.rating_comment ]
    assert_equal 7.0, MentorRating.of(@ana).average, "média por aluno: (6 + 8) / 2"

    follow_redirect!
    assert_select ".rolamentos-given", /8\/10/
    assert_select "form.review-rating-form", 0

    post training_session_ai_review_rating_path(session), params: { rating: { value: "1" } }
    assert_response :unprocessable_entity
    assert_equal 8, review.reload.rating, "avalia uma vez só"
  end

  test "outra pessoa não avalia a devolutiva do aprendiz" do
    session = clip_for(@learner, mentor: @ana)
    session.create_ai_review!(status: :pending).answer(@ana, **ANSWER)

    sign_in(complete_onboarding(account("intruso@example.com", nickname: "Intruso")))
    post training_session_ai_review_rating_path(session), params: { rating: { value: "1" } }
    assert_response :not_found
    assert_nil session.ai_review.reload.rating
  end

  test "o mentor escreve o resumo no Perfil e vê a média e o que os alunos disseram, sem nomes" do
    rated_review(@learner, @ana, 9).update!(rating_comment: "Muito paciente.")

    sign_in(@ana)
    get my_account_path
    assert_select "#mentor" do
      assert_select ".mentor-score", /9,0/
      assert_select ".mentor-feedback li", /Muito paciente/
      assert_select ".mentor-feedback li", text: /Rato/, count: 0
      assert_select "form[action=?] textarea[name='mentor_profile[bio]']", mentor_profile_path
    end

    patch mentor_profile_path, params: { mentor_profile: { bio: "Aulas de street. Instagram: @ana.skate" } }
    assert_redirected_to my_account_path(anchor: "mentor")
    assert_match "não pode ter telefone, e-mail, links ou @", flash[:alert]
    assert_match "dou aula de street", @ana.reload.mentor_bio, "o resumo antigo continua"

    patch mentor_profile_path, params: { mentor_profile: { bio: "Street e mini-rampa, 10 anos de sessão." } }
    assert_equal "Street e mini-rampa, 10 anos de sessão.", @ana.reload.mentor_bio

    sign_in(@learner)
    patch mentor_profile_path, params: { mentor_profile: { bio: "Sou mentor!" } }
    assert_response :not_found, "aprendiz não tem perfil de mentor"
  end

  test "mentor removido: os vídeos que o escolheram voltam para qualquer mentor" do
    session = clip_for(@learner, mentor: @ana)
    @ana.revoke_mentor!
    assert_nil session.reload.mentor
  end

  test "Meus dados traz o mentor escolhido e a nota dada" do
    review = rated_review(@learner, @ana, 7)
    data = DataExport.new(@learner, clip_url: ->(_) { "/videos/x" }).as_json
    session = data[:treinos_e_videos].find { |s| s[:sua_nota_ao_mentor] }

    assert_equal "Ana##{@ana.nickname_tag}", session[:mentor_escolhido]
    assert_equal 7, session[:sua_nota_ao_mentor][:rolamentos]
    assert_equal [ 7 ], DataExport.new(@ana, clip_url: ->(_) { "" }).as_json[:notas_que_voce_recebeu].map { it[:rolamentos] }
    assert_equal review.rated_at, session[:sua_nota_ao_mentor][:em]
  end
end
