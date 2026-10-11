# Números do perfil: XP e nível, estilo favorito e tarefas concluídas. A
# ofensiva tem regra própria, por sessão de skate (Streak).
#
# XP: cada tarefa concluída pela devolutiva do mentor vale 50 × (módulo + 1), ou
# seja, 50 no módulo 0, 100 no 1, 150 no 2 e 200 no 3. Tarefa pulada não vale XP.
# Nível: subir do nível N para o N+1 custa 100 × N de XP (100, 200, 300...), então
# cada nível pede mais que o anterior.
class ProfileStats
  XP_PER_MODULE = 50
  LEVEL_STEP    = 100

  Level = Data.define(:number, :floor, :ceiling) do
    def progress(xp) = ((xp - floor) * 100.0 / (ceiling - floor)).floor
  end

  def self.xp_for(maneuver) = XP_PER_MODULE * (maneuver.learning_module.position + 1)

  # XP total para chegar ao nível: 1 → 0, 2 → 100, 3 → 300, 4 → 600, 5 → 1000...
  def self.threshold(level) = LEVEL_STEP * level * (level - 1) / 2

  def self.level_for(xp)
    number = 1
    number += 1 while xp >= threshold(number + 1)
    Level.new(number: number, floor: threshold(number), ceiling: threshold(number + 1))
  end

  def initialize(user)
    @user = user
  end

  def xp = @xp ||= completed_maneuvers.sum { |maneuver| self.class.xp_for(maneuver) }
  def level = self.class.level_for(xp)
  def completed_count = completed_maneuvers.size
  def total_count = Maneuver.count

  # O estilo com mais treinos enviados; no empate, o treinado mais recentemente.
  def favorite_style
    sessions = submitted_sessions.includes(:maneuver).filter_map do |session|
      style = SkateStyle.for(session.maneuver)
      [ style, session.submitted_at ] if style
    end
    sessions.group_by(&:first).max_by { |_style, entries| [ entries.size, entries.map(&:last).max ] }&.first
  end

  private

  attr_reader :user

  def completed_maneuvers
    @completed_maneuvers ||= user.maneuver_progresses.status_completed.includes(maneuver: :learning_module).map(&:maneuver)
  end

  def submitted_sessions = user.training_sessions.where.not(submitted_at: nil)
end
