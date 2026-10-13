require "test_helper"

class MentorReviewTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"
  ANSWER = { headline: "Seu rolamento já está quase lá!",
             strengths: "Joelhos bem dobrados na hora de cair.",
             mistake: "A mão foi ao chão com o braço esticado.",
             next_focus: "Leve o queixo ao peito e role pelo ombro." }.freeze

  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "0.3", slug: "t-queda",
                                 name: "QUEDA CONTROLADA", position: 0, kind: :drill)
    @learner = account("aprendiz@example.com")
    @mentor  = account("mentor@example.com").tap(&:role_mentor!)
    @session = clip_for(@learner)
  end

  def account(contact)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      user.update!(birth_year: 1995, terms_accepted_at: Time.current)
    end
  end

  # Vídeo recém-gravado: o aprendiz ainda não registrou o resultado do treino.
  def clip_for(user)
    session = user.training_sessions.new(maneuver: @maneuver, scheduled_on: Date.current, status: :in_progress,
                                         gear_checked: true, ground_clear: true, space_safe: true)
    session.clip.attach(io: File.open(file_fixture("manobra.mp4"), "rb"), filename: "manobra.mp4", content_type: "video/mp4")
    session.save!
    session
  end

  def sign_in(user) = post session_path, params: { session: { contact: user.contact, password: PASSWORD } }
  def card(session) = "#" + ActionView::RecordIdentifier.dom_id(session, :mentor)

  test "o vídeo entra na fila assim que chega, mesmo sem o resultado do aprendiz" do
    sign_in(@mentor)
    get mentor_zine_path

    assert_select ".guide-tab.is-active", /Na fila \(1\)/
    assert_select card(@session) do
      assert_select "form.review-form[action=?]", mentor_video_review_path(@session)
      assert_select "textarea[name='review[strengths]'][required]"
      assert_select "button", /Enviar devolutiva/
    end
  end

  test "a devolutiva escrita no cartão chega ao aprendiz e o vídeo vai para Todos" do
    sign_in(@mentor)
    post mentor_video_review_path(@session), params: { review: ANSWER }

    assert_redirected_to mentor_zine_path(aba: "fila")
    review = @session.reload.ai_review
    assert review.status_completed?
    assert_equal @mentor, review.reviewer
    assert @session.status_analyzed?
    assert_equal "completed", TrackProgression.new(@learner).status_for(@maneuver), "a devolutiva conclui a tarefa"

    follow_redirect!
    assert_select ".guide-tab.is-active", /Na fila \(0\)/
    assert_select card(@session), 0, "saiu da fila"

    get mentor_zine_path(aba: "todos")
    assert_select card(@session) do
      assert_select ".zine-status.ok", /Devolutiva enviada em/
      assert_select ".review-summary", /Joelhos bem dobrados/
      assert_select "details.review-revise form[action=?]", mentor_video_review_path(@session)
    end

    delete sign_out_path
    sign_in(@learner)
    get training_session_ai_review_path(@session)
    assert_select ".screen-title", ANSWER[:headline]
    ANSWER.except(:headline).each_value { |text| assert_match text, response.body }
  end

  test "em Todos, o mentor revisa uma devolutiva já enviada" do
    sign_in(@mentor)
    post mentor_video_review_path(@session), params: { review: ANSWER }
    patch mentor_video_review_path(@session), params: { review: ANSWER.merge(next_focus: "Olhe para a frente na hora de rolar.") }

    assert_redirected_to mentor_zine_path(aba: "todos", anchor: ActionView::RecordIdentifier.dom_id(@session, :mentor))
    review = @session.reload.ai_review
    assert_equal "Olhe para a frente na hora de rolar.", review.next_focus
    assert review.revised_at.present?
    follow_redirect!
    assert_select card(@session) + " .zine-status.ok", /revisada em/
  end

  test "aprendiz que registra o resultado depois da devolutiva continua com ela pronta" do
    sign_in(@mentor)
    post mentor_video_review_path(@session), params: { review: ANSWER }
    delete sign_out_path

    sign_in(@learner)
    patch submit_training_session_path(@session), params: { training_session: { outcome: "felt_safe" } }
    assert_redirected_to training_session_ai_review_path(@session)
    assert @session.reload.status_analyzed?
    assert @session.ai_review.status_completed?
  end

  test "sem as três partes a devolutiva não é enviada e o texto digitado volta" do
    sign_in(@mentor)
    post mentor_video_review_path(@session), params: { review: ANSWER.merge(mistake: " ") }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_match "Escreva onde foi o erro.", response.body
    assert_match ANSWER[:strengths], response.body
    assert_nil @session.reload.ai_review
  end

  test "título vazio vira um título padrão" do
    sign_in(@mentor)
    post mentor_video_review_path(@session), params: { review: ANSWER.merge(headline: "") }

    assert_equal "Devolutiva do seu queda controlada", @session.reload.ai_review.headline
  end

  test "enviar de novo pela fila não sobrescreve a devolutiva" do
    sign_in(@mentor)
    post mentor_video_review_path(@session), params: { review: ANSWER }
    post mentor_video_review_path(@session), params: { review: ANSWER.merge(strengths: "Outro texto") }

    assert_equal ANSWER[:strengths], @session.reload.ai_review.strengths
  end

  test "aprendiz não responde e vídeo de mentor não entra na fila" do
    sign_in(@learner)
    post mentor_video_review_path(@session), params: { review: ANSWER }
    assert_response :not_found
    assert_nil @session.reload.ai_review

    delete sign_out_path
    sign_in(@mentor)
    mentor_session = clip_for(@mentor)
    post mentor_video_review_path(mentor_session), params: { review: ANSWER }
    assert_response :not_found
    get mentor_zine_path
    assert_select card(mentor_session), 0
  end
end
