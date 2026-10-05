# Cria ou apaga usuários de teste no banco de DESENVOLVIMENTO para conferir telas.
#
#   bin/rails runner .claude/skills/stance-responsivo/scripts/usuario_teste.rb criar [nivel]
#   bin/rails runner .claude/skills/stance-responsivo/scripts/usuario_teste.rb novo
#   bin/rails runner .claude/skills/stance-responsivo/scripts/usuario_teste.rb apagar
#
# criar  -> teste.prints@stance.dev: diagnóstico feito (nível padrão can_push, ou o
#           informado: never_ridden, can_push, stuck_on_ollie, advanced) e um treino com
#           vídeo na fila do mentor (para Zine, Resultado e Devolutiva).
# novo   -> teste.novo@stance.dev: só a conta, para Idade e Diagnóstico.
# apagar -> remove os dois (rode sempre ao terminar).
# Senha de ambos: senha1234
abort "Use só em desenvolvimento." unless Rails.env.development?

SENHA = "senha1234".freeze
EMAILS = { pronto: "teste.prints@stance.dev", novo: "teste.novo@stance.dev" }.freeze

def apagar_todos = EMAILS.each_value { |e| User.find_by(email: e)&.destroy! }

case ARGV[0]
when "criar"
  User.find_by(email: EMAILS[:pronto])&.destroy!
  user = User.register(contact: EMAILS[:pronto], password: SENHA, password_confirmation: SENHA)
  user.update!(birth_year: 2000, terms_accepted_at: Time.current)
  diagnosis = user.create_diagnosis!(level: ARGV[1].presence || "can_push", setup: :skateshop_board, completed_at: Time.current)
  diagnosis.diagnosis_blockers.create!(kind: :fear_of_falling)
  DiagnosisPlanner.new(diagnosis).apply!

  maneuver = TrackProgression.new(user).sync!.current_maneuver
  session = user.training_sessions.new(maneuver: maneuver, scheduled_on: Date.current, status: :in_progress,
                                       started_at: Time.current, gear_checked: true, ground_clear: true, space_safe: true)
  session.clip.attach(io: File.open(Rails.root.join("test/fixtures/files/manobra.mp4"), "rb"),
                      filename: "manobra.mp4", content_type: "video/mp4")
  session.save!
  session.update!(outcome: :felt_afraid)
  session.submit! # sem análise automática: o vídeo fica na fila do mentor
  puts "criado #{EMAILS[:pronto]} | manobra atual #{maneuver.slug} | treino #{session.id} (na fila do mentor)"
when "novo"
  User.find_by(email: EMAILS[:novo])&.destroy!
  User.register(contact: EMAILS[:novo], password: SENHA, password_confirmation: SENHA)
  puts "criado #{EMAILS[:novo]} (sem idade nem diagnóstico)"
when "apagar"
  apagar_todos
  puts "usuários de teste apagados"
else
  abort "Use: criar [nivel] | novo | apagar"
end
