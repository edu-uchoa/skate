# Chat entre um aprendiz e a equipe de mentores. Uma conversa por aprendiz, e todos
# os mentores e administradores leem e respondem: nenhum adulto conversa sozinho
# com um aprendiz (muitos são menores de idade), e quem chega depois vê o histórico.
class Conversation < ApplicationRecord
  belongs_to :learner, class_name: "User", inverse_of: :conversation
  has_many :messages, -> { order(:id) }, dependent: :delete_all, inverse_of: :conversation

  # Com mensagem nova do aprendiz que nenhum mentor abriu ainda.
  scope :unread_by_mentors, -> { where("learner_message_at > COALESCE(mentors_read_at, ?)", Time.zone.at(0)) }

  # A conversa do aprendiz; nasce na primeira mensagem.
  def self.for(learner)
    find_or_create_by!(learner: learner)
  rescue ActiveRecord::RecordNotUnique
    find_by!(learner: learner)
  end

  def unread_by_mentors? = learner_message_at.present? && (mentors_read_at.nil? || learner_message_at > mentors_read_at)
  def unread_by_learner? = mentor_message_at.present? && (learner_read_at.nil? || mentor_message_at > learner_read_at)
  def last_message_at = [ learner_message_at, mentor_message_at ].compact.max

  # Manda uma mensagem. Devolve a mensagem (com os erros, se não passou).
  def post!(author, body)
    message = messages.build(author: author, body: body)
    return message unless message.save

    now = message.created_at
    if author == learner
      update!(learner_message_at: now, learner_read_at: now)
    else
      update!(mentor_message_at: now, mentors_read_at: now)
    end
    message
  end

  # Quem abriu a conversa já leu tudo o que estava lá.
  def read_by!(viewer)
    return unless persisted?

    update_column(viewer == learner ? :learner_read_at : :mentors_read_at, Time.current)
  end
end
