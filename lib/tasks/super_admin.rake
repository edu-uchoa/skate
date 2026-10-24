# Super administrador (app/models/super_admin.rb): só o dono do app concede, da máquina
# dele. Rode no seu computador, no PowerShell (pedem a senha da chave):
#
#   ruby bin/rails super_admin:criar_chave                       # uma vez só
#   ruby bin/rails "super_admin:conceder[voce@gmail.com]"         # conta Google que já entrou aqui
#   ruby bin/rails "super_admin:conceder[uid:1234567890]"         # código Google (aparece no /painel)
#   ruby bin/rails super_admin:listar                             # o que vale em SUPER_ADMIN_GRANTS
#
# A chave particular fica em ~/.flipaai/super_admin_ed25519.pem, fora do projeto,
# trancada com a senha. Não copie para o GitHub, o Render ou outra pessoa.
require "io/console"

namespace :super_admin do
  def super_admin_key_path = Pathname(File.join(Dir.home, ".flipaai", "super_admin_ed25519.pem"))

  def super_admin_only_here!
    abort "Rode na sua máquina, não no servidor." if Rails.env.production?
  end

  def super_admin_passphrase(prompt)
    console = IO.console || abort("Rode no seu terminal (PowerShell): a senha é digitada sem aparecer.")
    console.getpass(prompt).to_s
  end

  desc "Cria a chave do dono (uma vez só): a particular fica nesta máquina, com senha"
  task criar_chave: :environment do
    super_admin_only_here!
    path = super_admin_key_path
    abort "Já existe uma chave em #{path}. Para trocar, apague o arquivo e rode de novo (as concessões antigas deixam de valer)." if path.exist?
    abort "A chave particular não pode ficar dentro do projeto." if path.expand_path.to_s.start_with?(Rails.root.to_s)

    passphrase = super_admin_passphrase("Crie uma senha para a chave (12 caracteres ou mais): ")
    abort "Senha curta demais: use 12 caracteres ou mais." if passphrase.length < 12
    abort "As senhas não conferem." unless super_admin_passphrase("Repita a senha: ") == passphrase

    private_pem, public_pem = SuperAdmin.generate_key(passphrase)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, private_pem)
    File.chmod(0o600, path)
    File.write(SuperAdmin::PUBLIC_KEY_PATH, public_pem)

    puts <<~TEXTO
      Chave criada.
        Particular (só nesta máquina, com a sua senha): #{path}
        Pública (vai no código):                        #{SuperAdmin::PUBLIC_KEY_PATH.relative_path_from(Rails.root)}
      Guarde uma cópia da chave particular num lugar seguro (ex.: pendrive). Sem ela e a senha, ninguém mais dá acesso de super admin.
      Próximo passo: ruby bin/rails "super_admin:conceder[seu-email@gmail.com]"
    TEXTO
  end

  desc "Gera a concessão de super admin para uma conta Google (pede a senha da chave)"
  task :conceder, [ :conta ] => :environment do |_, args|
    super_admin_only_here!
    target = args[:conta].to_s.strip
    abort 'Diga a conta: ruby bin/rails "super_admin:conceder[voce@gmail.com]" (ou [uid:CODIGO])' if target.empty?

    if target.start_with?("uid:")
      uid, email = target.delete_prefix("uid:").strip, nil
    else
      user = User.find_by(email: target.downcase)
      abort "Nenhuma conta Google com #{target} neste computador. Entre uma vez com ela aqui, ou use [uid:CODIGO] (aparece no /painel)." unless user&.google?
      uid, email = user.google_uid, user.email
    end
    abort "Código Google vazio." if uid.empty?

    path = super_admin_key_path
    abort "Sem chave nesta máquina (#{path}). Rode antes: ruby bin/rails super_admin:criar_chave" unless path.exist?
    begin
      private_key = SuperAdmin.load_private_key(path.read, super_admin_passphrase("Senha da chave: "))
    rescue OpenSSL::PKey::PKeyError
      abort "Senha errada."
    end

    token = SuperAdmin.sign(uid: uid, email: email, private_key: private_key)
    abort "A chave pública do projeto não é a desta chave: confira config/super_admin_public_key.pem." unless SuperAdmin.verify(token)

    puts <<~TEXTO

      Concessão de super admin para #{email || "a conta Google #{uid}"}:

      #{token}

      Para valer, coloque em SUPER_ADMIN_GRANTS (várias? separe por vírgula):
        Render: Environment > SUPER_ADMIN_GRANTS > salvar (o serviço reinicia).
        Este computador (PowerShell): setx SUPER_ADMIN_GRANTS "#{token}"  e reinicie o VS Code e o servidor.
      Para tirar o acesso, apague a concessão da variável.
    TEXTO
  end

  desc "Mostra as concessões que valem em SUPER_ADMIN_GRANTS"
  task listar: :environment do
    tokens = ENV.fetch("SUPER_ADMIN_GRANTS", "").split(",").map(&:strip).compact_blank
    grants = SuperAdmin.grants
    puts "Sem a chave pública do projeto (#{SuperAdmin::PUBLIC_KEY_PATH.relative_path_from(Rails.root)}): ninguém é super admin." unless SuperAdmin.public_key
    grants.each { |grant| puts "#{grant.email || "(sem e-mail)"} · conta Google #{grant.uid} · concedida em #{grant.issued_at}" }
    puts "#{grants.size} válida(s), #{tokens.size - grants.size} inválida(s) (ignoradas)."
  end
end
