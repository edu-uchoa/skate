# Administradores: aprovam e removem mentores e têm todas as funções de mentor.
# Não existe caminho no app para virar administrador: só quem tem acesso ao
# projeto/servidor roda estes comandos (pelo e-mail ou telefone da conta).
#
#   bin/rails "admin:promover[voce@email.com]"
#   bin/rails "admin:remover[voce@email.com]"
#   bin/rails admin:listar
namespace :admin do
  def admin_find!(contact)
    User.find_registered_by_contact(contact.to_s) || abort("Nenhuma conta encontrada para #{contact.inspect}.")
  end

  desc "Transforma uma conta existente em administrador"
  task :promover, [ :contato ] => :environment do |_, args|
    user = admin_find!(args[:contato])
    user.update!(role: :admin, mentor_requested_at: nil)
    puts "#{user.contact} agora é administrador."
  end

  desc "Volta um administrador para aprendiz e encerra as sessões dele"
  task :remover, [ :contato ] => :environment do |_, args|
    user = admin_find!(args[:contato])
    abort "#{user.contact} não é administrador." unless user.role_admin?
    user.revoke_mentor!
    puts "#{user.contact} voltou a ser aprendiz."
  end

  desc "Lista os administradores"
  task listar: :environment do
    admins = User.role_admin.order(:created_at)
    puts admins.any? ? admins.map(&:contact) : "Nenhum administrador cadastrado."
  end
end
