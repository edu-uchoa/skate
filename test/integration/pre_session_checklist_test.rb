require "test_helper"

# Checklist pré-sessão (Praticar este passo): o botão vermelho leva à tela Gravar com a
# manobra e o checklist já marcados; "Registrar sem enviar vídeo" segue para o resultado.
class PreSessionChecklistTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"
  CHECKLIST = { gear_checked: "1", ground_clear: "1", space_safe: "1" }.freeze

  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "0.1", slug: "t-setup", name: "SETUP",
                                 position: 0, kind: :drill, description: "Monte o seu skate.")
    @user = User.register(contact: "aprendiz@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    @user.update!(birth_year: 2000, terms_accepted_at: Time.current)
    @user.create_diagnosis!(level: :never_ridden, setup: :store_board, completed_at: Time.current)
    post session_path, params: { session: { contact: @user.contact, password: PASSWORD } }
  end

  def checklist(fields, **extra) = post(maneuver_training_sessions_path(@maneuver), params: { training_session: fields, **extra })

  test "os itens são checkboxes de verdade e os dois botões dependem do checklist" do
    get new_maneuver_training_session_path(@maneuver)
    assert_select "label.check-item input.check-input[type=checkbox]", 3
    assert_select "button[type=submit][data-checklist-target=submit]", 2
    assert_select "button[name=gravar]", /Gravar o vídeo do treino/
    assert_select "[data-checklist-target=hint]", /Marque os três itens/
    assert_select ".check-item[onclick]", 0, "o visual não depende mais de clique no cartão"
  end

  test "checklist incompleto avisa em vez de não fazer nada" do
    assert_no_difference -> { TrainingSession.count } do
      checklist(CHECKLIST.merge(space_safe: "0"), gravar: "1")
    end
    assert_response :unprocessable_entity
    assert_match "Marque os três itens do checklist", response.body
  end

  test "o botão vermelho leva à tela Gravar com a manobra e o checklist já marcados" do
    assert_no_difference -> { TrainingSession.count } do
      checklist(CHECKLIST, gravar: "1")
    end
    assert_redirected_to new_recording_path(maneuver_slug: @maneuver.slug, checklist: "ok")

    follow_redirect!
    assert_select "select[name='recording[maneuver_slug]'] option[selected][value=?]", @maneuver.slug
    assert_select ".rec-check input[type=checkbox][checked]", 3
  end

  test "registrar sem vídeo cria o treino e segue para o resultado" do
    assert_difference -> { TrainingSession.count }, 1 do
      checklist(CHECKLIST)
    end
    session = TrainingSession.last
    assert_redirected_to result_training_session_path(session)
    assert session.status_in_progress?
  end
end
