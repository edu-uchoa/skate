require "test_helper"

class ZineTest < ActionDispatch::IntegrationTest
  CHECKLIST = { gear_checked: "1", ground_clear: "1", space_safe: "1" }.freeze

  setup do
    learning_module = LearningModule.create!(code: "9", name: "TESTE", position: 99)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "9.0", slug: "t-ollie",
                                 name: "OLLIE", position: 0)
    @user = sign_up_onboarded("zine@example.com")
  end

  def sign_up_onboarded(contact)
    post account_path, params: { user: { contact: contact, password: "manobra123", password_confirmation: "manobra123" } }
    User.last.tap do |user|
      user.update!(birth_year: 2000, terms_accepted_at: Time.current)
      user.create_diagnosis!(level: :never_ridden, setup: :store_board, completed_at: Time.current)
    end
  end

  def record_clip
    clip = fixture_file_upload("manobra.mp4", "video/mp4", true)
    post recording_path, params: { recording: { clip: clip, maneuver_slug: @maneuver.slug, duration_seconds: "6", source: "camera", **CHECKLIST } },
                         headers: { "Accept" => "application/json" }
    @user.training_sessions.last
  end

  test "a Zine exige login" do
    delete sign_out_path
    get zine_path
    assert_redirected_to new_session_path
  end

  test "sem vídeos mostra o convite para gravar" do
    get zine_path
    assert_response :success
    assert_match "ainda não gravou", response.body
    assert_select "a[href=?]", new_recording_path
  end

  test "vídeo gravado aparece na Zine automaticamente, aguardando o resultado" do
    session = record_clip

    get zine_path
    assert_response :success
    assert_select "##{ActionView::RecordIdentifier.dom_id(session, :zine)}" do
      assert_select "video[src*='active_storage']"
      assert_select "h3", "OLLIE"
      assert_select ".zine-status", /Registre o resultado/
      assert_select "a[href=?]", result_training_session_path(session)
    end
    assert_select "[data-controller=poll]", count: 0
  end

  test "mostra o andamento: fila, análise, pronta e falha" do
    session = record_clip
    patch submit_training_session_path(session), params: { training_session: { outcome: "felt_safe" } }
    review = session.reload.ai_review

    { "pending"    => [ /Na fila da análise/, "Acompanhar análise", true ],
      "processing" => [ /Analisando/,         "Acompanhar análise", true ],
      "completed"  => [ /Devolutiva pronta/,  "Ver devolutiva",     false ],
      "failed"     => [ /Não foi possível/,   "Ver detalhes",       false ] }.each do |status, (label, action, polling)|
      review.update_columns(status: AiReview.statuses[status])

      get zine_path
      assert_select ".zine-status", label
      assert_select "a.zine-action[href=?]", training_session_ai_review_path(session), text: /#{action}/
      assert_select "[data-controller=poll]", count: polling ? 1 : 0
    end
  end

  test "cada usuário só vê os próprios vídeos" do
    record_clip
    delete sign_out_path

    sign_up_onboarded("outro@example.com")
    get zine_path
    assert_match "ainda não gravou", response.body
  end

  test "treinos sem vídeo não entram na Zine" do
    @user.training_sessions.create!(maneuver: @maneuver, scheduled_on: Date.current, status: :scheduled)
    get zine_path
    assert_match "ainda não gravou", response.body
  end
end
