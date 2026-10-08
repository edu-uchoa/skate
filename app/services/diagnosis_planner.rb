# Traduz o diagnóstico (nível + travas + setup) em:
#   - um texto de validação ("Entendido. Você está começando do zero...")
#   - o nó de entrada na trilha (a 0.1 para todo mundo)
#   - drills recomendados por causa das travas declaradas
#
# O diagnóstico não pula tarefas: a seta da trilha começa na 0.1 e só anda com a
# devolutiva do mentor. Quem já domina uma tarefa usa "Avançar para a próxima tarefa".
class DiagnosisPlanner
  BLOCKER_DRILLS = {
    "fear_of_falling" => "0.3",   # queda controlada
    "foot_technique"  => "1.0"    # postura
  }.freeze

  def initialize(diagnosis)
    @diagnosis = diagnosis
  end

  def entry_maneuver
    Maneuver.ordered.first || raise("A trilha não possui manobras cadastradas. Execute bin/rails db:seed.")
  end

  def recommended_drills
    codes = diagnosis.diagnosis_blockers.filter_map { |b| BLOCKER_DRILLS[b.kind] }
    codes << "0.2" if diagnosis.setup_no_board?
    Maneuver.where(code: codes.uniq).ordered
  end

  # Frase de espelho da tela "Validação de diagnóstico".
  def summary
    [ level_phrase, blocker_phrase, setup_phrase ].compact.to_sentence(
      words_connector: ", ", last_word_connector: " e "
    ).upcase_first + "."
  end

  def reassurance
    if diagnosis.setup_no_board?
      "O maior erro é ir para a pista lotada com um skate inadequado. Vamos começar seguros."
    elsif diagnosis.diagnosis_blockers.any?(&:kind_fear_of_falling?)
      "Antes de qualquer manobra, você vai aprender a cair. Isso muda tudo."
    else
      "Você começa pelo básico. O que já domina, dá para avançar na página de cada tarefa."
    end
  end

  # Aplica o plano: destrava a trilha a partir da 0.1.
  def apply!
    TrackProgression.new(diagnosis.user).sync!
  end

  private

  attr_reader :diagnosis

  def level_phrase
    {
      "never_ridden"   => "você está começando do zero",
      "can_push"       => "você já rema e faz curvas",
      "stuck_on_ollie" => "você está travado no ollie",
      "advanced"       => "você já manda ollie com firmeza"
    }[diagnosis.level]
  end

  def blocker_phrase
    kinds = diagnosis.diagnosis_blockers.map(&:kind)
    return if kinds.empty?

    parts = []
    parts << "quer treinar sem plateia"          if kinds.include?("shame")
    parts << "quer aprender a cair primeiro"     if kinds.include?("fear_of_falling")
    parts << "precisa acertar a base dos pés"    if kinds.include?("foot_technique")
    parts << "ainda não tem um lugar bom"        if kinds.include?("no_place")
    parts.to_sentence(words_connector: ", ", last_word_connector: " e ").presence
  end

  def setup_phrase
    "não tem skate ainda" if diagnosis.setup_no_board?
  end
end
