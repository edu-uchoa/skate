# Média de rolamentos de cada mentor, das avaliações que os aprendizes deixam nas
# devolutivas (AiReview#rate), de 1 a 10.
#
# É uma média por aluno: primeiro a média de cada aprendiz com aquele mentor, depois a
# média entre os aprendizes. Assim quem avalia muitas vezes (ou um amigo do mentor)
# não pesa mais que os outros.
class MentorRating
  Score = Data.define(:average, :learners)

  # { mentor_id => Score } dos mentores que já foram avaliados (os outros ficam de fora).
  def self.for(mentors)
    per_learner = AiReview.rated.where(reviewer_id: Array(mentors).map(&:id)).joins(:training_session)
                          .group(:reviewer_id, "training_sessions.user_id").average(:rating)

    per_learner.group_by { |(mentor_id, _learner_id), _average| mentor_id }.transform_values do |rows|
      averages = rows.map { |_key, average| average.to_f }
      Score.new(average: (averages.sum / averages.size).round(1), learners: averages.size)
    end
  end

  def self.of(mentor) = self.for([ mentor ])[mentor.id]

  # Mentores do mais bem avaliado para o menos; os ainda sem avaliação vão no fim.
  def self.ranked(mentors, scores)
    mentors.sort_by.with_index { |mentor, index| [ -(scores[mentor.id]&.average || -1), index ] }
  end
end
