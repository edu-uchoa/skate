# Rolamentos: a nota de 1 a 10 que o aprendiz dá ao mentor na devolutiva, e a média do
# mentor (MentorRating), que aparece na hora de escolher quem avalia o vídeo.
module RolamentosHelper
  # As esferas do rolamento, em volta do centro (8 delas).
  BALLS = 8.times.map { |i| [ (12 + 6.6 * Math.cos(i * Math::PI / 4)).round(2), (12 + 6.6 * Math.sin(i * Math::PI / 4)).round(2) ] }.freeze

  # Ícone de rolamento de skate (anel por fora, esferas e o miolo), na cor do texto.
  def rolamento_icon(css_class = "rolamento")
    tag.svg(class: css_class, viewBox: "0 0 24 24", "aria-hidden": "true", focusable: "false") do
      safe_join([
        tag.circle(cx: 12, cy: 12, r: 10.6, fill: "none", stroke: "currentColor", "stroke-width": 2.2),
        tag.circle(cx: 12, cy: 12, r: 3.2, fill: "none", stroke: "currentColor", "stroke-width": 2.2),
        *BALLS.map { |x, y| tag.circle(cx: x, cy: y, r: 1.75, fill: "currentColor") }
      ])
    end
  end

  # Média do mentor: "◎ 8,7 · 12 alunos avaliaram" (ou "Sem avaliações ainda").
  def mentor_score(score)
    tag.span(class: "mentor-score") do
      if score
        safe_join([ rolamento_icon, tag.strong(rolamentos_number(score.average)),
                    tag.span("· #{pluralize(score.learners, "aluno avaliou", plural: "alunos avaliaram")}") ], " ")
      else
        safe_join([ rolamento_icon, tag.span("Sem avaliações ainda") ], " ")
      end
    end
  end

  def rolamentos_number(value) = number_with_precision(value, precision: 1, separator: ",")

  # Nome do mentor para o aprendiz: o nickname, com o #0000 menor.
  def mentor_name(mentor)
    return "Mentor ##{mentor.id}" if mentor.nickname.blank?
    safe_join([ mentor.nickname, tag.small("##{mentor.nickname_tag}") ])
  end
end
