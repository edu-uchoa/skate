require "test_helper"

# O IP de quem usa o app, do jeito que o pedido chega no Render: pessoa -> Cloudflare ->
# Render -> Thruster -> Puma. Cada etapa soma ao X-Forwarded-For o IP de quem lhe
# entregou o pedido, e o Thruster fala com o Puma pelo 127.0.0.1.
class ClientIpTest < ActiveSupport::TestCase
  PESSOA     = "203.0.113.7"
  CLOUDFLARE = "162.158.41.226"
  RENDER     = "10.0.0.5"

  # O request.remote_ip com os intermediários de produção (Skate::TRUSTED_PROXIES).
  def remote_ip(forwarded_for)
    env = Rack::MockRequest.env_for("/", "REMOTE_ADDR" => "127.0.0.1", "HTTP_X_FORWARDED_FOR" => forwarded_for)
    ActionDispatch::RemoteIp.new(->(_) { }, true, Skate::TRUSTED_PROXIES).call(env)
    ActionDispatch::Request.new(env).remote_ip
  end

  test "o IP é o da pessoa, não o do servidor da Cloudflare" do
    assert_equal PESSOA, remote_ip("#{PESSOA}, #{CLOUDFLARE}, #{RENDER}")
  end

  test "também com a Cloudflare em IPv6" do
    assert_equal "2001:db8::7", remote_ip("2001:db8::7, 2606:4700::1, #{RENDER}")
  end

  test "um IP inventado no começo da lista não vale" do
    assert_equal PESSOA, remote_ip("1.1.1.1, #{PESSOA}, #{CLOUDFLARE}, #{RENDER}")
  end

  test "quem fala direto com o Render não se passa pela Cloudflare" do
    assert_equal "198.51.100.9", remote_ip("#{PESSOA}, #{CLOUDFLARE}, 198.51.100.9, #{RENDER}")
  end
end
