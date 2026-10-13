require "test_helper"

class StreakFlowTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"
  ANSWER = { strengths: "Boa base.", mistake: "Olhou para o chão.", next_focus: "Olhe para a frente." }.freeze

  setup do
    # Meio da tarde: o rolê de "uma hora atrás até daqui a uma hora" cabe no mesmo dia
    # (perto da meia-noite, o fim caía no dia seguinte e o teste falhava).
    travel_to Time.current.in_time_zone(User.new.time_zone).change(hour: 15)
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "0.1", slug: "t-setup", name: "SETUP",
                                 position: 0, kind: :drill, description: "Monte o seu skate.")
    @learner = account("ofensiva@example.com")
    @learner.create_diagnosis!(level: :never_ridden, setup: :store_board, completed_at: Time.current)
    @mentor = account("mentor@example.com").tap(&:role_mentor!)
  end

  def account(contact)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      user.update!(birth_year: 2000, terms_accepted_at: Time.current)
    end
  end

  def sign_in(user) = post session_path, params: { session: { contact: user.contact, password: PASSWORD } }

  def record_and_submit
    post recording_path, headers: { "Accept" => "application/json" }, params: {
      recording: { clip: fixture_file_upload("manobra.mp4", "video/mp4", true), maneuver_slug: @maneuver.slug,
                   duration_seconds: "5", source: "camera", gear_checked: "1", ground_clear: "1", space_safe: "1" }
    }
    session = @learner.training_sessions.last
    patch submit_training_session_path(session), params: { training_session: { outcome: "felt_safe" } }
    session.reload
  end

  test "vídeo gravado fora de um rolê não vale para a ofensiva" do
    sign_in(@learner)
    session = record_and_submit

    assert_not session.recorded_at_meetup?
    assert_empty @learner.skate_sessions
  end

  test "rolê no mapa + vídeo no horário + resultado = sessão; a devolutiva do mentor valida" do
    @learner.meetups.create!(place_name: "Pista do parque", latitude: -15.79, longitude: -47.88, day: Date.current,
                             start_time: 1.hour.ago.in_time_zone(@learner.time_zone).strftime("%H:%M"),
                             end_time: 1.hour.from_now.in_time_zone(@learner.time_zone).strftime("%H:%M"))
    sign_in(@learner)

    get new_recording_path
    assert_select ".rec-meetup", /Pista do parque/
    session = record_and_submit

    assert session.recorded_at_meetup?
    skate_session = @learner.skate_sessions.sole
    assert_not skate_session.validated?
    assert_equal 1, Streak.new(@learner).count, "já conta enquanto espera o mentor"

    delete sign_out_path
    sign_in(@mentor)
    get mentor_zine_path
    assert_match "a sessão fica validada na ofensiva", response.body
    post mentor_video_review_path(session), params: { review: ANSWER }
    assert skate_session.reload.validated?
  end

  test "apagar o vídeo antes da devolutiva tira a sessão da ofensiva" do
    @learner.meetups.create!(place_name: "Pista", latitude: -15.79, longitude: -47.88, day: Date.current,
                             start_time: 1.hour.ago.in_time_zone(@learner.time_zone).strftime("%H:%M"),
                             end_time: 1.hour.from_now.in_time_zone(@learner.time_zone).strftime("%H:%M"))
    sign_in(@learner)
    session = record_and_submit

    delete clip_path(session)
    assert_empty @learner.skate_sessions.reload
  end

  test "a página mostra primeiro como funciona e depois o campo de justificativa" do
    sign_in(@learner)
    get streak_path
    assert_response :success
    assert_operator response.body.index("Como funciona"), :<, response.body.index("Justificar uma parada")
    assert_select "form[action=?]", streak_justifications_path, 0, "sem sessão ainda, não há o que justificar"

    @learner.skate_sessions.create!(skated_on: 10.days.ago.to_date)
    get streak_path
    assert_select ".streak-status .guide-tag", "Perdida"
    assert_select "form[action=?] textarea[name='streak_justification[reason]']", streak_justifications_path
  end

  test "justificar segura a ofensiva até o mentor decidir; aprovar mantém, recusar perde" do
    @learner.skate_sessions.create!(skated_on: 4.days.ago.to_date)
    @learner.skate_sessions.create!(skated_on: 10.days.ago.to_date)
    sign_in(@learner)

    post streak_justifications_path, params: { streak_justification: { reason: "  " } }
    assert_response :unprocessable_entity
    assert_select ".auth-errors", /Conte o motivo da parada/

    post streak_justifications_path, params: { streak_justification: { reason: "Torci o tornozelo." } }
    assert_redirected_to streak_path(anchor: "justificar")
    justification = @learner.streak_justifications.sole
    assert justification.status_pending?

    post streak_justifications_path, params: { streak_justification: { reason: "De novo" } }
    assert_equal 1, @learner.streak_justifications.count, "uma justificativa por parada"

    travel 8.days do
      assert_equal :frozen, Streak.new(@learner).state
      assert_equal 2, Streak.new(@learner).count

      delete sign_out_path
      sign_in(@mentor)
      get mentor_streak_justifications_path
      assert_select ".mentor-tabs .guide-tab.is-active", /Ofensivas \(1\)/
      assert_select "#" + ActionView::RecordIdentifier.dom_id(justification), text: /Torci o tornozelo/
      assert_no_match @learner.contact, response.body, "o mentor vê o contato mascarado"

      patch mentor_streak_justification_path(justification, decision: "approve")
      assert_redirected_to mentor_streak_justifications_path
      assert justification.reload.status_approved?
      assert_equal @mentor, justification.reviewer
      assert_equal :paused, Streak.new(@learner).state
      assert_equal 2, Streak.new(@learner).count
    end
  end

  test "aprendiz não vê a aba de ofensivas do mentor" do
    sign_in(@learner)
    get mentor_streak_justifications_path
    assert_response :not_found
  end
end
