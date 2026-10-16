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

  test "toda conta nova é aprendiz, e não existe mais cadastro como mentor" do
    sign_up_with_google("esperto@example.com")
    assert User.find_by(email: "esperto@example.com").role_learner?

    delete sign_out_path
    get root_path
    assert_select "input[name=account_type]", 0, "a entrada não tem a opção Conta Mentor"
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
