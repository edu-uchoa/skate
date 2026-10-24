# Super administrador: só as contas que o dono do app autoriza, da máquina dele.
#
# Cada autorização é uma "concessão" assinada com a chave particular do dono (Ed25519).
# A chave particular fica só no computador dele, trancada com uma senha que só ele sabe
# (bin/rails super_admin:criar_chave), e nunca vai para o GitHub nem para o Render. O app
# guarda só a chave pública (config/super_admin_public_key.pem, no código) e confere a
# assinatura: quem mexe nas variáveis do Render ou no banco não consegue fabricar uma
# concessão.
#
# A concessão vale para uma conta Google (o código que o Google dá à conta e que nunca
# muda), e não para um e-mail: ligar um Google qualquer a uma conta antiga que tenha o
# e-mail do dono não dá acesso.
#
# As concessões ficam na variável SUPER_ADMIN_GRANTS, separadas por vírgula. Tirar uma de
# lá desfaz o acesso; uma concessão inválida (alterada, ou de outra chave) é ignorada e
# avisada no log.
module SuperAdmin
  VERSION = "v1"
  PURPOSE = "flipaai-super-admin" # assinado junto: a assinatura não serve para outra coisa
  PUBLIC_KEY_PATH = Rails.root.join("config/super_admin_public_key.pem")

  Grant = Data.define(:uid, :email, :issued_at)

  class << self
    # Só os testes trocam a chave pública (no app, vale sempre a do arquivo do projeto;
    # de propósito, nenhuma variável de ambiente troca a chave).
    attr_writer :public_key

    def granted?(user)
      uid = user&.google_uid
      uid.present? && grants.any? { |grant| grant.uid == uid }
    end

    # Concessões válidas da variável SUPER_ADMIN_GRANTS (lidas de novo quando ela muda).
    def grants
      raw = ENV.fetch("SUPER_ADMIN_GRANTS", "")
      key = public_key
      return @grants if @grants && @grants_raw == raw && @grants_key.equal?(key)

      @grants_raw, @grants_key = raw, key
      @grants = raw.split(",").map(&:strip).compact_blank.filter_map do |token|
        verify(token).tap do |grant|
          Rails.logger.warn("[FlipaAi] concessão de super admin inválida ignorada (#{token.first(16)}…)") unless grant
        end
      end
    end

    # A concessão, se a assinatura for da chave do dono; senão nil.
    def verify(token)
      version, payload, signature = token.to_s.split(".")
      return if version != VERSION || payload.blank? || signature.blank? || public_key.nil?

      data = decode(payload)
      return unless public_key.verify(nil, decode(signature), "#{PURPOSE}.#{data}")

      fields = JSON.parse(data)
      Grant.new(uid: fields.fetch("uid").to_s, email: fields["email"], issued_at: fields["issued_at"])
    rescue ArgumentError, JSON::ParserError, KeyError, OpenSSL::PKey::PKeyError
      nil
    end

    # Na máquina do dono: a concessão para a conta Google uid, assinada com a chave dele.
    def sign(uid:, email:, private_key:)
      data = { uid: uid.to_s, email: email, issued_at: Time.current.utc.iso8601 }.to_json
      [ VERSION, encode(data), encode(private_key.sign(nil, "#{PURPOSE}.#{data}")) ].join(".")
    end

    # Na máquina do dono: um par de chaves novo. A particular sai trancada com a senha.
    def generate_key(passphrase)
      key = OpenSSL::PKey.generate_key("ED25519")
      [ key.private_to_pem(OpenSSL::Cipher.new("aes-256-cbc"), passphrase), key.public_to_pem ]
    end

    # Abre a chave particular com a senha (OpenSSL::PKey::PKeyError se a senha estiver errada).
    def load_private_key(pem, passphrase) = OpenSSL::PKey.read(pem, passphrase)

    # A chave pública do projeto (lida uma vez), ou nil sem o arquivo: aí ninguém é super admin.
    def public_key
      return @public_key if @public_key
      return @file_public_key if defined?(@file_public_key)

      @file_public_key = (OpenSSL::PKey.read(PUBLIC_KEY_PATH.read) if PUBLIC_KEY_PATH.exist?)
    end

    private

    def encode(bytes) = Base64.urlsafe_encode64(bytes, padding: false)
    def decode(text) = Base64.urlsafe_decode64(text)
  end
end
