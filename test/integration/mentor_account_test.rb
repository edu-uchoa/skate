require "test_helper"
require "rake"

class MentorAccountTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("mentor:promover")
  end

  teardown do
    %w[mentor:promover mentor:remover].each { |task| Rake::Task[task].reenable }
  end

  test "toda conta nova é aprendiz, mesmo tentando se cadastrar como mentor" do
    post account_path, params: { user: { contact: "esperto@example.com", password: PASSWORD,
                                         password_confirmation: PASSWORD, role: "mentor" } }

    assert User.last.role_learner?
  end

  test "promover e remover mentor pelo terminal" do
    user = User.register(contact: "mentor@example.com", password: PASSWORD, password_confirmation: PASSWORD)

    assert_output(/agora é mentor/) { Rake::Task["mentor:promover"].invoke("mentor@example.com") }
    assert user.reload.role_mentor?

    assert_output(/voltou a ser aprendiz/) { Rake::Task["mentor:remover"].invoke("MENTOR@example.com") }
    assert user.reload.role_learner?
  end

  test "promover uma conta que não existe para com erro" do
    assert_raises(SystemExit) do
      capture_io { Rake::Task["mentor:promover"].invoke("ninguem@example.com") }
    end
  end
end
