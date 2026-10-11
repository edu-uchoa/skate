# Estilos de skate do perfil (os mesmos tipos de skate do Deck).
#
# O estilo favorito sai das tarefas que a pessoa treina na trilha: cada manobra
# conta para um estilo; as tarefas de base (setup, equipamento, queda, postura,
# equilíbrio, empurrar e parar) não contam para nenhum. Para mudar, edite a lista.
module SkateStyle
  NAMES = { "street" => "Street", "bowl" => "Bowl", "old_school" => "Old school", "new_school" => "New school" }.freeze

  BY_MANEUVER = {
    "1.4" => "bowl",       # curva frontside: carving de transição
    "1.5" => "bowl",       # curva backside
    "2.0" => "old_school", # tic-tac, clássico do freestyle dos anos 70
    "2.1" => "bowl",       # fakie, andar de costas nas transições
    "2.2" => "new_school", # manual, base do street técnico atual
    "3.0" => "street",     # shove-it
    "3.1" => "old_school", # no comply, clássico dos anos 80
    "3.2" => "street"      # ollie
  }.freeze

  def self.for(maneuver) = BY_MANEUVER[maneuver.code]
  def self.name(key) = NAMES[key]
end
