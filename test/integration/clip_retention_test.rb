require "test_helper"

# Prazo dos vídeos: cada vídeo é apagado exatamente 1 mês depois do envio, e a pessoa
# vê o dia e a hora no cartão do vídeo.
class ClipRetentionTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PASSWORD = "manobra123"

  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "0.3", slug: "t-queda",
                                 name: "QUEDA CONTROLADA", position: 0, kind: :drill)
    @learner = User.register(contact: "aprendiz@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    @learner.update!(birth_year: 2000, terms_accepted_at: Time.current)
    @learner.create_diagnosis!(level: :never_ridden, setup: :store_board, completed_at: Time.current)
  end

  def sign_in = post(session_path, params: { session: { contact: @learner.contact, password: PASSWORD } })

  def clip_for(user)
    session = user.training_sessions.new(maneuver: @maneuver, scheduled_on: Date.current, status: :submitted,
                                         submitted_at: Time.current, outcome: :felt_safe,
                                         gear_checked: true, ground_clear: true, space_safe: true)
    File.open(file_fixture("manobra.mp4"), "rb") do |io|
      session.clip.attach(io: io, filename: "manobra.mp4", content_type: "video/mp4")
      session.save!
    end
    session.create_ai_review!(status: :pending)
    session
  end

  test "o prazo conta exatamente 1 mês da hora do envio e aparece no cartão" do
    travel_to Time.zone.local(2026, 10, 19, 10, 49) do
      video = clip_for(@learner)
      assert_equal Time.zone.local(2026, 11, 19, 10, 49), video.clip_expires_at

      sign_in
      get zine_path
      assert_select ".zine-expiry", /Será apagado em 31 dias, em 19\/11\/2026 às 07:49/ # fuso de São Paulo
      assert_match "Cada vídeo é apagado sozinho 1 mês depois do envio", response.body
    end
  end

  test "a versão em 720p não recomeça o prazo" do
    video = nil
    travel_to(10.days.ago) { video = clip_for(@learner) }
    uploaded = video.clip_uploaded_at

    video.replace_clip_with(File.open(file_fixture("manobra.mp4"), "rb"), metadata: { "transcoded" => true })
    assert_equal uploaded, video.reload.clip_uploaded_at
  end

  test "passou de 1 mês: a limpeza apaga o vídeo e a devolutiva já enviada continua" do
    old = nil
    travel_to(1.month.ago - 1.minute) { old = clip_for(@learner) }
    old.ai_review.update!(status: :completed, strengths: "Base firme.", mistake: "Braço.", next_focus: "Ombro.")
    fresh = clip_for(@learner)

    assert_equal 1, PurgeExpiredClipsJob.perform_now
    assert_not old.reload.clip.attached?
    assert old.ai_review.status_completed?, "a devolutiva fica"
    assert fresh.reload.clip.attached?
  end

  test "vídeo vencido some da Zine e não abre mais, mesmo antes da limpeza automática" do
    old = nil
    travel_to(1.month.ago - 1.minute) { old = clip_for(@learner) }
    sign_in

    get clip_path(old)
    assert_response :not_found
    assert_not old.reload.clip.attached?

    old2 = nil
    travel_to(1.month.ago - 1.minute) { old2 = clip_for(@learner) }
    get zine_path
    assert_select "##{ActionView::RecordIdentifier.dom_id(old2, :zine)}", 0
  end

  test "faltando menos de 3 dias, o aviso fica em destaque" do
    travel_to(1.month.ago + 2.days) { clip_for(@learner) }
    sign_in
    get zine_path
    assert_select ".zine-expiry.is-soon", /em 2 dias/
  end
end
