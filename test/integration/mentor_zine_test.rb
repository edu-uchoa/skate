require "test_helper"

class MentorZineTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "0.3", slug: "t-queda",
                                 name: "QUEDA CONTROLADA", position: 0, kind: :drill)

    @teen   = account("aprendiz.um@example.com", birth_year: Date.current.year - 15)
    @adult  = account("aprendiz.dois@example.com", birth_year: 1995)
    @mentor = account("mentor@example.com", birth_year: 1990).tap(&:role_mentor!)

    @teen_clip   = clip_for(@teen, review: :pending)
    @adult_clip  = clip_for(@adult, review: :completed)
    @mentor_clip = clip_for(@mentor, review: :pending)
  end

  def account(contact, birth_year:)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      user.update!(birth_year: birth_year, terms_accepted_at: Time.current)
    end
  end

  def clip_for(user, review:)
    session = user.training_sessions.new(maneuver: @maneuver, scheduled_on: Date.current, status: :submitted,
                                         submitted_at: Time.current, outcome: :felt_afraid,
                                         gear_checked: true, ground_clear: true, space_safe: true)
    session.clip.attach(io: File.open(file_fixture("manobra.mp4"), "rb"), filename: "manobra.mp4", content_type: "video/mp4")
    session.save!
    session.create_ai_review!(status: review)
    session
  end

  def sign_in(contact) = post session_path, params: { session: { contact: contact, password: PASSWORD } }

  test "sem login vai para o login; aprendiz recebe página não encontrada" do
    get mentor_zine_path
    assert_redirected_to new_session_path

    sign_in("aprendiz.um@example.com")
    get mentor_zine_path
    assert_response :not_found
    assert_select "a[href=?]", mentor_zine_path, count: 0
  end

  test "a fila mostra só quem espera devolutiva, sem o contato completo" do
    sign_in("mentor@example.com")
    get mentor_zine_path

    assert_response :success
    assert_select "#" + ActionView::RecordIdentifier.dom_id(@teen, :mentor) do
      assert_select "strong", "ap•••@example.com"
      assert_select ".guide-tag", "Menor de idade"
      assert_select "#" + ActionView::RecordIdentifier.dom_id(@teen_clip, :mentor)
    end
    assert_select "#" + ActionView::RecordIdentifier.dom_id(@adult, :mentor), count: 0, message: "devolutiva pronta não fica na fila"
    assert_select "#" + ActionView::RecordIdentifier.dom_id(@mentor_clip, :mentor), count: 0, message: "vídeo de mentor não é de aprendiz"
    assert_select ".guide-tab.is-active", /Na fila \(1\)/
    assert_match "Fez com medo", response.body
    assert_no_match "aprendiz.um@example.com", response.body
    assert_select "a[href=?]", mentor_zine_path
  end

  test "a aba todos separa os vídeos por aprendiz" do
    sign_in("mentor@example.com")
    get mentor_zine_path(aba: "todos")

    assert_select ".mentor-learner", 2
    assert_select "#" + ActionView::RecordIdentifier.dom_id(@adult, :mentor) do
      assert_select ".zine-status", /Devolutiva pronta/
    end
    assert_select ".guide-tab.is-active", /Todos \(2\)/
  end

  test "avisa quando o vídeo passou do prazo de 48h" do
    @teen_clip.ai_review.update_columns(created_at: 3.days.ago)
    sign_in("mentor@example.com")
    get mentor_zine_path

    assert_select ".zine-status.error", /passou do prazo de 48h/
  end
end
