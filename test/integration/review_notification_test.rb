require "test_helper"

# Aviso de devolutiva nova: quando o mentor envia (ou revisa) a devolutiva, o ícone
# Zine do aprendiz ganha um número, igual ao "Na fila" do mentor. Some quando ele abre.
class ReviewNotificationTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"
  ANSWER = { headline: "Quase lá!", strengths: "Joelhos dobrados.",
             mistake: "Braço esticado na queda.", next_focus: "Role pelo ombro." }.freeze

  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "0.3", slug: "t-queda",
                                 name: "QUEDA CONTROLADA", position: 0, kind: :drill)
    @learner = account("aprendiz@example.com")
    @learner.create_diagnosis!(level: :never_ridden, setup: :store_board, completed_at: Time.current)
    @mentor = account("mentor@example.com").tap(&:role_mentor!)
    @session = @learner.training_sessions.new(maneuver: @maneuver, scheduled_on: Date.current, status: :submitted,
                                              submitted_at: Time.current, outcome: :felt_safe,
                                              gear_checked: true, ground_clear: true, space_safe: true)
    @session.clip.attach(io: File.open(file_fixture("manobra.mp4"), "rb"), filename: "manobra.mp4", content_type: "video/mp4")
    @session.save!
    @session.create_ai_review!(status: :pending)
  end

  def account(contact)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      user.update!(birth_year: 1995, terms_accepted_at: Time.current)
    end
  end

  def sign_in(user) = post(session_path, params: { session: { contact: user.contact, password: PASSWORD } })
  def zine_badge = ".phone-bottom-nav a[href='#{zine_path}'] .nav-badge"
  def card = "#" + ActionView::RecordIdentifier.dom_id(@session, :zine)

  test "devolutiva enviada aparece como número no ícone Zine até o aprendiz abrir" do
    sign_in(@learner)
    get zine_path
    assert_select zine_badge, 0, "sem devolutiva ainda, sem número"
    delete sign_out_path

    sign_in(@mentor)
    post mentor_video_review_path(@session), params: { review: ANSWER }
    delete sign_out_path

    sign_in(@learner)
    get track_path
    assert_select zine_badge, "1"
    get zine_path
    assert_select "#{card} .zine-new", "Nova"

    get training_session_ai_review_path(@session)
    assert_response :success
    assert_select zine_badge, 0, "abriu a devolutiva: o número some"
    get zine_path
    assert_select "#{card} .zine-new", 0
  end

  test "devolutiva revisada pelo mentor volta a avisar, como atualizada" do
    @session.ai_review.answer(@mentor, **ANSWER)
    @session.ai_review.mark_seen!

    travel 1.minute do
      @session.ai_review.revise(**ANSWER, mistake: "Olhou para baixo.")
    end

    sign_in(@learner)
    travel 2.minutes do
      get zine_path
      assert_select zine_badge, "1"
      assert_select "#{card} .zine-new", "Atualizada"
    end
  end

  test "o número conta só as devolutivas da própria pessoa" do
    @session.ai_review.answer(@mentor, **ANSWER)
    other = account("outra@example.com")
    other.create_diagnosis!(level: :never_ridden, setup: :store_board, completed_at: Time.current)

    sign_in(other)
    get zine_path
    assert_select zine_badge, 0
  end
end
