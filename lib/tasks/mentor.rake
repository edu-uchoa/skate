# Contas de mentor. No app, a pessoa pede para ser mentor no cadastro e um mentor
# aprova em /mentor/pedidos. Pelo terminal, quem acessa o servidor promove direto
# uma conta já criada (é assim que nasce o primeiro mentor).
#
#   bin/rails "mentor:promover[voce@email.com]"
#   bin/rails "mentor:remover[voce@email.com]"
#   bin/rails mentor:listar
namespace :mentor do
  def mentor_find!(contact)
    User.find_registered_by_contact(contact.to_s) || abort("Nenhuma conta encontrada para #{contact.inspect}.")
  end

  desc "Transforma uma conta existente em mentor"
  task :promover, [ :contato ] => :environment do |_, args|
    user = mentor_find!(args[:contato])
    user.approve_mentor!
    puts "#{user.contact} agora é mentor."
  end

  desc "Volta uma conta de mentor para aprendiz"
  task :remover, [ :contato ] => :environment do |_, args|
    user = mentor_find!(args[:contato])
    user.role_learner!
    puts "#{user.contact} voltou a ser aprendiz."
  end

  desc "Lista as contas de mentor"
  task listar: :environment do
    mentors = User.role_mentor.order(:created_at)
    puts mentors.any? ? mentors.map(&:contact) : "Nenhum mentor cadastrado."
  end
end
