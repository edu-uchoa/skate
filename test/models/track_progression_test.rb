require "test_helper"

class TrackProgressionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!
    @learning_module = LearningModule.create!(code: "9", name: "TESTE", position: 99)
    @first  = Maneuver.create!(learning_module: @learning_module, code: "9.0", slug: "t-primeiro",
                               name: "PRIMEIRO", position: 0)
    @second = Maneuver.create!(learning_module: @learning_module, code: "9.1", slug: "t-segundo",
                               name: "SEGUNDO", position: 1, prerequisite: @first)
  end

  def submitted_session(maneuver, outcome: :felt_safe)
    @user.training_sessions.create!(maneuver: maneuver, scheduled_on: Date.current, outcome: outcome, status: :submitted)
  end

  test "o primeiro nó sem pré-requisito fica disponível e o seguinte, bloqueado" do
    progression = TrackProgression.new(@user).sync!

    assert_equal "available", progression.status_for(@first)
    assert_equal "locked",    progression.status_for(@second)
    assert_equal @first, progression.current_maneuver
  end

  test "enviar o treino não conclui a tarefa, nem quando a pessoa se sentiu segura" do
    progression = TrackProgression.new(@user).sync!
    progression.record_attempt!(submitted_session(@first))

    assert_equal "in_progress", progression.status_for(@first)
    assert_equal "locked",      progression.status_for(@second)
    assert_equal @first, progression.current_maneuver, "a seta só anda com a devolutiva do mentor"
  end

  test "a devolutiva do mentor conclui a tarefa e a seta vai para a próxima" do
    progression = TrackProgression.new(@user).sync!
    progression.record_attempt!(submitted_session(@first))
    progression.complete!(@first)

    assert_equal "completed", progression.status_for(@first)
    assert_equal "available", progression.status_for(@second)
    assert_equal @second, progression.current_maneuver
  end

  test "avançar sem devolutiva pula a tarefa: sem check, destrava a próxima e a seta anda" do
    progression = TrackProgression.new(@user).sync!

    assert progression.skip!(@first)
    assert_equal "skipped",   progression.status_for(@first)
    assert_equal "available", progression.status_for(@second)
    assert_equal @second, progression.current_maneuver
    assert_equal 0, progression.completed_count, "pular não conta como concluído"

    progression.complete!(@first) # o mentor respondeu depois
    assert_equal "completed", progression.status_for(@first)
  end

  test "não dá para pular tarefa bloqueada nem a já concluída" do
    progression = TrackProgression.new(@user).sync!
    assert_not progression.skip!(@second)
    assert_equal "locked", progression.status_for(@second)

    progression.complete!(@first)
    assert_not progression.skip!(@first)
    assert_equal "completed", progression.status_for(@first)
  end
end
