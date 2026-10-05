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
    @review  = @session.ai_review
  end

  def account(contact)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      user.update!(birth_year: 1995, terms_accepted_at: Time.current)
    end
  end

  def clip_for(user)
    session = user.training_sessions.new(maneuver: @maneuver, scheduled_on: Date.current, status: :submitted,
                                         submitted_at: Time.current, outcome: :felt_afraid,
                                         gear_checked: true, ground_clear: true, space_safe: true)
    session.clip.attach(io: File.open(file_fixture("manobra.mp4"), "rb"), filename: "manobra.mp4", content_type: "video/mp4")
    session.save!
    session.create_ai_review!(status: :pending)
    session
  end

  def sign_in(user) = post session_path, params: { session: { contact: user.contact, password: PASSWORD } }

  test "o mentor responde e o aprendiz vê a devolutiva na tela de sempre" do
    sign_in(@mentor)
    get mentor_zine_path
    assert_select "a[href=?]", edit_mentor_review_path(@review), text: /Responder/

    get edit_mentor_review_path(@review)
    assert_response :success
    assert @review.reload.status_processing?, "o aprendiz passa a ver que o mentor está vendo"

    patch mentor_review_path(@review), params: { review: ANSWER }
    assert_redirected_to mentor_zine_path
    @review.reload
    assert @review.status_completed?
    assert_equal @mentor, @review.reviewer
    assert @session.reload.status_analyzed?

    delete sign_out_path
    sign_in(@learner)
    get training_session_ai_review_path(@session)
    assert_select ".screen-title", ANSWER[:headline]
    ANSWER.except(:headline).each_value { |text| assert_match text, response.body }
    assert_no_match "fila do mentor", response.body

    get zine_path
    assert_select ".zine-status", /Devolutiva pronta/
  end

  test "sem as três partes a devolutiva não é enviada" do
    sign_in(@mentor)
    patch mentor_review_path(@review), params: { review: ANSWER.merge(mistake: " ") }

    assert_response :unprocessable_entity
    assert_match "Escreva onde foi o erro.", response.body
    assert_not @review.reload.status_completed?
  end

  test "título vazio vira um título padrão" do
    sign_in(@mentor)
    patch mentor_review_path(@review), params: { review: ANSWER.merge(headline: "") }

    assert_equal "Devolutiva do seu queda controlada", @review.reload.headline
  end

  test "uma devolutiva enviada não é sobrescrita" do
    sign_in(@mentor)
    patch mentor_review_path(@review), params: { review: ANSWER }
    patch mentor_review_path(@review), params: { review: ANSWER.merge(strengths: "Outro texto") }

    assert_equal ANSWER[:strengths], @review.reload.strengths
  end

  test "aprendiz não responde e vídeo de mentor não entra na fila" do
    sign_in(@learner)
    get edit_mentor_review_path(@review)
    assert_response :not_found
    patch mentor_review_path(@review), params: { review: ANSWER }
    assert_response :not_found
    assert @review.reload.status_pending?

    delete sign_out_path
    sign_in(@mentor)
    mentor_review = clip_for(@mentor).ai_review
    get edit_mentor_review_path(mentor_review)
    assert_response :not_found
  end
end
