require "test_helper"

# Topo do app: o ☰ abre o painel de atalhos (antes só mostrava "Menu (em breve)") e o
# botão de ajuda (?) leva à Ajuda (antes não fazia nada).
class AppMenuTest < ActionDispatch::IntegrationTest
  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    Maneuver.create!(learning_module: learning_module, code: "0.1", slug: "t-setup", name: "SETUP",
                     position: 0, kind: :drill, description: "Monte o seu skate.")
  end

  test "aprendiz: o ☰ abre os atalhos e o ? leva à Ajuda" do
    complete_onboarding(sign_up_with_google("menu@example.com"))
    get track_path

    assert_select ".phone-header-bar button[data-action='app-menu#toggle'][aria-controls='app-menu-panel'][aria-expanded=false]"
    assert_no_match "Menu (em breve)", response.body
    assert_select "#app-menu-panel[hidden]" do
      [ tasks_path, streak_path, chat_path, new_schedule_path, new_support_request_path, install_path, privacy_path, terms_path ].each do |path|
        assert_select "a.app-menu-item[href=?]", path
      end
      assert_select "form[action=?] button.app-menu-item", sign_out_path
    end
    assert_select ".app-menu-backdrop[hidden][data-action='click->app-menu#close']"
    assert_select ".phone-header-bar a.help-btn[href=?]", new_support_request_path
  end

  test "mentor: o menu não tem as telas de aprendiz" do
    mentor = User.register(contact: "mentor@example.com", password: "manobra123", password_confirmation: "manobra123")
    mentor.update!(role: :mentor, birth_year: 1990)
    post session_path, params: { session: { contact: mentor.contact, password: "manobra123" } }
    get mentor_zine_path

    assert_select "#app-menu-panel" do
      assert_select "a[href=?]", new_support_request_path
      assert_select "a[href=?]", tasks_path, 0
      assert_select "a[href=?]", chat_path, 0
    end
  end

  test "antes de terminar o cadastro não há topo nem menu" do
    sign_up_with_google("cadastro@example.com")
    get onboarding_age_gate_path
    assert_select "#app-menu-panel", 0
  end
end
