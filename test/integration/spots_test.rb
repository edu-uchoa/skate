require "test_helper"

class SpotsTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    @user  = account("picos@example.com")
    @other = account("outra@example.com")
    sign_in(@user)
  end

  def account(contact)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      complete_onboarding(user) # Picos exige o cadastro completo
    end
  end

  def sign_in(user) = post session_path, params: { session: { contact: user.contact, password: PASSWORD } }

  def meetup_params(**overrides)
    { meetup: { place_name: "Pista do parque", latitude: "-15.793900", longitude: "-47.882800",
                day: Date.tomorrow.iso8601, start_time: "16:00", end_time: "18:00", note: "Levo um shape extra" }.merge(overrides) }
  end

  test "a página só mostra o mapa depois que a localização é liberada" do
    get spots_path
    assert_response :success

    assert_select "[data-controller=spots-map][data-spots-map-center-value=?]", "[-15.7939,-47.8828]" # Brasília
    assert_select "[data-spots-map-target=asking]:not([hidden])"
    assert_select "[data-spots-map-target=denied][hidden]"
    assert_select "[data-spots-map-target=content][hidden]", 1, "sem localização, nada do mapa aparece"
    assert_select "form.spots-form[hidden]", 1, "o formulário abre ao tocar no mapa"
  end

  test "os picos fixos aparecem no mapa e na lista" do
    original = Rails.configuration.x.flipaai.spots_file
    file = Tempfile.new([ "picos", ".yml" ])
    file.write({ "picos" => [ { "nome" => "Pista teste", "tipo" => "pista", "descricao" => "Piso liso.",
                                "lat" => -15.79, "lng" => -47.88 } ] }.to_yaml)
    file.close
    Rails.configuration.x.flipaai.spots_file = file.path

    get spots_path
    assert_select "#spot_0 strong", "Pista teste"
    assert_select "#spot_0 [data-action='spots-map#pickSpot'][data-spots-map-index-param='0']"
    assert_includes css_select("[data-controller=spots-map]").first["data-spots-map-spots-value"], "Pista teste"
  ensure
    Rails.configuration.x.flipaai.spots_file = original
    file&.unlink
  end

  test "marcar um rolê: aparece em Seus rolês com o link para os amigos" do
    assert_difference -> { @user.meetups.count }, 1 do
      post meetups_path, params: meetup_params
    end
    meetup = @user.meetups.last
    assert_redirected_to spots_path(anchor: "meetup_#{meetup.id}")

    follow_redirect!
    assert_select "#meetup_#{meetup.id}" do
      assert_select "strong", "Pista do parque"
      assert_select ".spots-card-when", meetup.schedule_label
      assert_select "[data-share-url-value=?]", shared_meetup_url(meetup.share_token)
      assert_select "a[href=?]", meetup.google_maps_url
    end
  end

  test "com erro, o formulário volta aberto com a mensagem" do
    post meetups_path, params: meetup_params(start_time: "18:00", end_time: "16:00")

    assert_response :unprocessable_entity
    assert_select "form.spots-form:not([hidden]) .auth-errors", /O horário de fim precisa ser depois do começo/
  end

  test "o link para os amigos abre sem login e não mostra quem marcou" do
    post meetups_path, params: meetup_params
    meetup = @user.meetups.last
    delete sign_out_path

    get shared_meetup_path(meetup.share_token)
    assert_response :success
    assert_select ".auth-card-value", "Pista do parque"
    assert_select ".auth-card-value", meetup.schedule_label
    assert_select "a[href=?]", meetup.google_maps_url, text: /Abrir no Google Maps/
    assert_match "Levo um shape extra", response.body
    assert_no_match "picos@example.com", response.body
    assert_match "noindex", response.headers["X-Robots-Tag"]
  end

  test "cancelar o rolê faz o link parar de funcionar" do
    post meetups_path, params: meetup_params
    meetup = @user.meetups.last

    delete meetup_path(meetup)
    assert_redirected_to spots_path

    get shared_meetup_path(meetup.share_token)
    assert_response :not_found
    assert_select ".screen-title", "Esse rolê já acabou"
  end

  test "depois do horário de fim, o rolê some e o link para de funcionar" do
    post meetups_path, params: meetup_params
    meetup = @user.meetups.last

    travel_to meetup.ends_at + 1.minute do
      get shared_meetup_path(meetup.share_token)
      assert_response :not_found

      get spots_path
      assert_not Meetup.exists?(meetup.id), "rolê que acabou é apagado"
    end
  end

  test "não dá para cancelar o rolê de outra pessoa, e ninguém vê o rolê dos outros" do
    others = @other.meetups.create!(meetup_params[:meetup])

    delete meetup_path(others)
    assert_response :not_found
    assert Meetup.exists?(others.id)

    get spots_path
    assert_select "#meetup_#{others.id}", 0
  end
end
