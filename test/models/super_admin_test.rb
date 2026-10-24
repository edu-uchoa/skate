require "test_helper"

# Super admin só com a concessão assinada pela chave do dono (SuperAdmin).
class SuperAdminTest < ActiveSupport::TestCase
  def google_user(uid, email)
    User.create!(email: email, google_uid: uid, registered_at: Time.current)
  end

  test "só a conta Google da concessão é super admin, não o e-mail" do
    grant_super_admin("google-dono")
    owner = google_user("google-dono", "dono@example.com")
    other = google_user("google-outro", "outro@example.com")

    assert owner.super_admin?
    assert_not other.super_admin?
    owner.update_columns(google_uid: "google-outro-dono") # mesmo e-mail, outra conta Google
    assert_not owner.reload.super_admin?, "a concessão é da conta Google, não do e-mail"
    assert_not User.new(email: "dono@example.com").super_admin?, "sem Google, nunca"
  end

  test "concessão alterada, de outra chave ou quebrada não vale" do
    grant_super_admin("google-dono")
    real = ENV["SUPER_ADMIN_GRANTS"]
    version, _payload, signature = real.split(".")
    forged_payload = Base64.urlsafe_encode64({ uid: "google-intruso", email: nil, issued_at: Time.current.iso8601 }.to_json, padding: false)
    other_key = OpenSSL::PKey.generate_key("ED25519")

    [ "#{version}.#{forged_payload}.#{signature}",                                          # trocou a conta, mesma assinatura
      SuperAdmin.sign(uid: "google-intruso", email: nil, private_key: other_key),            # assinada com outra chave
      "v1.lixo.lixo", "v2.#{forged_payload}.#{signature}", "qualquer-coisa", "" ].each do |token|
      assert_nil SuperAdmin.verify(token), token
    end

    ENV["SUPER_ADMIN_GRANTS"] = [ real, SuperAdmin.sign(uid: "google-intruso", email: nil, private_key: other_key) ].join(",")
    assert_equal [ "google-dono" ], SuperAdmin.grants.map(&:uid), "só a concessão verdadeira vale"
  end

  test "tirar a concessão da variável tira o acesso" do
    grant_super_admin("google-dono")
    owner = google_user("google-dono", "dono@example.com")
    assert owner.super_admin?

    ENV["SUPER_ADMIN_GRANTS"] = ""
    assert_not owner.super_admin?
  end

  test "sem a chave pública do projeto, ninguém é super admin" do
    grant_super_admin("google-dono")
    owner = google_user("google-dono", "dono@example.com")
    original = SuperAdmin.method(:public_key)
    SuperAdmin.define_singleton_method(:public_key) { nil } # como se o arquivo não existisse
    assert_not owner.super_admin?
  ensure
    SuperAdmin.define_singleton_method(:public_key, original) if original
  end

  test "a chave particular só abre com a senha" do
    private_pem, public_pem = SuperAdmin.generate_key("uma senha bem comprida")
    assert_includes private_pem, "ENCRYPTED PRIVATE KEY", "a chave sai trancada"

    key = SuperAdmin.load_private_key(private_pem, "uma senha bem comprida")
    SuperAdmin.public_key = OpenSSL::PKey.read(public_pem)
    token = SuperAdmin.sign(uid: "google-dono", email: "dono@example.com", private_key: key)
    assert_equal "google-dono", SuperAdmin.verify(token).uid

    assert_raises(OpenSSL::PKey::PKeyError) { SuperAdmin.load_private_key(private_pem, "senha errada") }
  end
end
