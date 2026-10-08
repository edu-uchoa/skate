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

  test "o primeiro nó sem pré-requisito fica disponível e o seguinte, bloqueado" do
    progression = TrackProgression.new(@user).sync!

    assert_equal "available", progression.status_for(@first)
    assert_equal "locked",    progression.status_for(@second)
  end

  test "concluir o pré-requisito destrava o próximo nó" do
    progression = TrackProgression.new(@user).sync!
    session = @user.training_sessions.create!(maneuver: @first, scheduled_on: Date.current,
                                              outcome: :felt_safe, status: :submitted)

    progression.record_attempt!(session)

    assert_equal "completed", TrackProgression.new(@user).sync!.status_for(@first)
    assert_equal "available", TrackProgression.new(@user).sync!.status_for(@second)
  end

  test "o diagnóstico pula os nós anteriores sem dar como concluídos" do
    third = Maneuver.create!(learning_module: @learning_module, code: "9.2", slug: "t-terceiro",
                             name: "TERCEIRO", position: 2, prerequisite: @second)

    progression = TrackProgression.new(@user).start_at!(@second)

    assert_equal "skipped",   progression.status_for(@first)
    assert_equal "available", progression.status_for(@second), "o nó pulado destrava o ponto de entrada"
    assert_equal "locked",    progression.status_for(third)
    assert_equal @second, progression.current_maneuver
    assert_equal 0, progression.completed_count, "nada foi treinado ainda"
  end

  test "treinar com sucesso um nó pulado conclui; o que já foi concluído não volta a pulado" do
    progression = TrackProgression.new(@user).start_at!(@second)
    session = @user.training_sessions.create!(maneuver: @first, scheduled_on: Date.current,
                                              outcome: :felt_safe, status: :submitted)
    progression.record_attempt!(session)
    assert_equal "completed", progression.status_for(@first)

    TrackProgression.new(@user).start_at!(@second) # refazer o diagnóstico
    assert_equal "completed", TrackProgression.new(@user).status_for(@first)
  end
end
