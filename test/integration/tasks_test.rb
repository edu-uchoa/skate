require "test_helper"

class TasksTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    base   = LearningModule.create!(code: "0", name: "BASE", position: 0)
    tricks = LearningModule.create!(code: "3", name: "PRIMEIRAS MANOBRAS", position: 3)
    @setup    = Maneuver.create!(learning_module: base, code: "0.1", slug: "t-setup", name: "SETUP", position: 0, kind: :drill)
    @gear     = Maneuver.create!(learning_module: base, code: "0.2", slug: "t-gear", name: "EQUIPAMENTO", position: 1, prerequisite: @setup)
    @fall     = Maneuver.create!(learning_module: base, code: "0.3", slug: "t-queda", name: "QUEDA", position: 2, prerequisite: @gear)
    @shove_it = Maneuver.create!(learning_module: tricks, code: "3.0", slug: "t-shove-it", name: "SHOVE-IT", position: 0, prerequisite: @fall)

    @user = User.register(contact: "tarefas@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    @user.update!(birth_year: 2000, terms_accepted_at: Time.current)
    post session_path, params: { session: { contact: @user.contact, password: PASSWORD } }
  end

  test "o cartão Tarefas concluídas do Perfil é um botão para a lista" do
    get my_account_path
    assert_select "a.profile-stat.is-button[href=?]", tasks_path, text: /0 de 4\s*Tarefas concluídas/
  end

  test "lista as concluídas, de forma breve, e as que faltam, com a situação de cada uma" do
    progression = TrackProgression.new(@user).sync!
    progression.complete!(@setup)
    progression.skip!(@gear)

    get tasks_path
    assert_response :success
    assert_select ".tasks-summary .streak-count strong", "1"
    assert_select ".tasks-summary", /50 XP ganhos/

    assert_select ".tasks-item.is-done", 1
    assert_select ".tasks-item.is-done[href=?]", maneuver_path(@setup) do
      assert_select "strong", "0.1 · SETUP"
      assert_select "small", /Concluída em \d{2}\/\d{2} · \+50 XP/
    end

    { @gear => "Pulada", @fall => "Agora", @shove_it => "Bloqueada" }.each do |maneuver, label|
      assert_select ".tasks-item[href=?] .guide-tag", maneuver_path(maneuver), label
    end
  end

  test "sem nenhuma concluída, a lista explica como concluir" do
    get tasks_path
    assert_match "quando o mentor responder, ela aparece aqui", response.body
    assert_select ".tasks-item", 4
  end
end
