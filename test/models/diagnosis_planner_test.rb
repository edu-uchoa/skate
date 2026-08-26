require "test_helper"

class DiagnosisPlannerTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(birth_year: 2000, terms_accepted_at: Time.current)
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    Maneuver.create!(learning_module: learning_module, code: "0.1", slug: "setup",
                     name: "SETUP", position: 0)
    @diagnosis = @user.create_diagnosis!(level: :never_ridden, setup: :no_board)
    @diagnosis.diagnosis_blockers.create!(kind: :shame)
  end

  test "resume o diagnóstico em uma frase" do
    summary = DiagnosisPlanner.new(@diagnosis).summary

    assert_includes summary, "começando do zero"
    assert_includes summary, "sem plateia"
    assert_includes summary, "não tem skate ainda"
  end

  test "aplica o plano no primeiro nó da trilha" do
    DiagnosisPlanner.new(@diagnosis).apply!

    assert_equal "available", @user.maneuver_progresses.first.status
  end
end
