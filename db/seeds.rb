# Conteúdo base da trilha do Sakte.
#
# Idempotente: pode rodar quantas vezes quiser (bin/rails db:seed).
# Os códigos ("0.1", "1.2", "3.2") são a referência usada pelo DiagnosisPlanner.

ActiveRecord::Base.transaction do
  modules = {
    "0" => { name: "BASE",         subtitle: "Antes de subir", position: 0,
             description: "Setup, equipamento e a habilidade mais importante: cair bem." },
    "1" => { name: "FUNDAMENTOS",  subtitle: "Domínio do chão", position: 1,
             description: "Postura, equilíbrio, propulsão e controle de direção." },
    "2" => { name: "TRANSIÇÃO",    subtitle: "Peso e eixo", position: 2,
             description: "Transferência de peso — a base de qualquer manobra aérea." },
    "3" => { name: "PRIMEIRAS MANOBRAS", subtitle: "Do chão ao ar", position: 3,
             description: "As manobras que abrem todo o resto do skate." }
  }

  modules.each do |code, attrs|
    LearningModule.find_or_initialize_by(code: code).update!(attrs)
  end

  maneuvers = [
    { code: "0.1", slug: "escolher-setup",   name: "SETUP",             module_code: "0", kind: :drill,
      description: "Entenda que skate comprar (ou ajustar) para o que você quer fazer.",
      difficulty: :beginner, average_time: "1 dia" },
    { code: "0.2", slug: "equipamento",      name: "EQUIPAMENTO",       module_code: "0", kind: :drill,
      description: "Capacete e joelheira: o que é obrigatório e o que é opcional.",
      difficulty: :beginner, average_time: "1 dia", prerequisite: "0.1" },
    { code: "0.3", slug: "queda-controlada", name: "QUEDA CONTROLADA",  module_code: "0", kind: :drill,
      description: "Aprenda a cair antes de aprender a andar. Reduz 90% dos machucados.",
      difficulty: :beginner, average_time: "15 min", prerequisite: "0.2", requires_clip: true,
      steps: [ "Escolha um piso macio (grama ou carpete).",
               "Flexione os joelhos e role de ombro no chão.",
               "Nunca tente parar a queda esticando os braços." ] },

    { code: "1.0", slug: "postura",   name: "POSTURA",   module_code: "1", kind: :maneuver,
      description: "Descubra se você é regular ou goofy e fixe a base dos pés.",
      difficulty: :beginner, average_time: "1 sessão", prerequisite: "0.3" },
    { code: "1.1", slug: "equilibrio", name: "EQUILÍBRIO", module_code: "1", kind: :maneuver,
      description: "Fique em cima da board parado, sem tensionar os ombros.",
      difficulty: :beginner, average_time: "1 sessão", prerequisite: "1.0" },
    { code: "1.2", slug: "empurrar",  name: "EMPURRAR",  module_code: "1", kind: :maneuver,
      description: "Domine a técnica de propulsão mantendo o centro de massa estabilizado no pé base.",
      difficulty: :beginner, average_time: "1-2 semanas", prerequisite: "1.1" },
    { code: "1.3", slug: "parar",     name: "PARAR",     module_code: "1", kind: :maneuver,
      description: "Foot brake e tail scrape: parar com controle em qualquer velocidade.",
      difficulty: :beginner, average_time: "1 semana", prerequisite: "1.2" },
    { code: "1.4", slug: "curva-fs",  name: "CURVA FS",  module_code: "1", kind: :maneuver,
      description: "Curva frontside usando só o peso dos calcanhares.",
      difficulty: :beginner, average_time: "1 semana", prerequisite: "1.3" },
    { code: "1.5", slug: "curva-bs",  name: "CURVA BS",  module_code: "1", kind: :maneuver,
      description: "Curva backside, o espelho da anterior.",
      difficulty: :beginner, average_time: "1 semana", prerequisite: "1.4" },

    { code: "2.0", slug: "tic-tac",   name: "TIC-TAC",   module_code: "2", kind: :maneuver,
      description: "Ganhe velocidade sem remar, girando o nose no ar.",
      difficulty: :intermediate, average_time: "1 semana", prerequisite: "1.5" },
    { code: "2.1", slug: "fakie",     name: "FAKIE",     module_code: "2", kind: :maneuver,
      description: "Andar de costas com a mesma base. Prepara o corpo para manobras invertidas.",
      difficulty: :intermediate, average_time: "1-2 semanas", prerequisite: "2.0" },
    { code: "2.2", slug: "manual",    name: "MANUAL",    module_code: "2", kind: :assessment,
      description: "Equilíbrio sobre o truck traseiro. É a avaliação técnica do módulo.",
      why_now: "Sem o manual você não tem o controle de eixo necessário para estabilizar o ollie na queda.",
      difficulty: :intermediate, average_time: "2 semanas", prerequisite: "2.1", requires_clip: true },

    { code: "3.0", slug: "shove-it",  name: "SHOVE-IT",  module_code: "3", kind: :maneuver,
      description: "Gire a board 180° embaixo dos pés, sem pular.",
      difficulty: :intermediate, average_time: "1-2 semanas", prerequisite: "2.2" },
    { code: "3.1", slug: "no-comply", name: "NO COMPLY", module_code: "3", kind: :maneuver,
      description: "Um pé no chão, o outro levanta a board. Transição natural para o ollie.",
      difficulty: :intermediate, average_time: "2 semanas", prerequisite: "3.0" },
    { code: "3.2", slug: "ollie",     name: "OLLIE",     module_code: "3", kind: :maneuver,
      description: "O fundamento que abre todo o resto do skate.",
      why_now: "Se você tentar pular direto para o Ollie sem dominar o manual (2.2), não terá o equilíbrio " \
               "necessário para estabilizar a board na queda. O fundamento de transferência e distribuição " \
               "de peso é idêntico. Construa a base, depois voe.",
      difficulty: :intermediate, average_time: "2-3 semanas", prerequisite: "3.1", requires_clip: true }
  ]

  maneuvers.each_with_index do |attrs, index|
    steps = attrs.delete(:steps)
    prerequisite_code = attrs.delete(:prerequisite)
    learning_module = LearningModule.find_by!(code: attrs.delete(:module_code))

    maneuver = Maneuver.find_or_initialize_by(code: attrs[:code])
    maneuver.update!(
      attrs.merge(
        learning_module: learning_module,
        position: index,
        prerequisite: prerequisite_code && Maneuver.find_by(code: prerequisite_code)
      )
    )

    next if steps.blank?

    maneuver.instruction_steps.destroy_all
    steps.each_with_index do |body, i|
      maneuver.instruction_steps.create!(position: i + 1, body: body)
    end
  end
end

puts "Trilha: #{LearningModule.count} módulos, #{Maneuver.count} nós."
