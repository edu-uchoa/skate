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
end
