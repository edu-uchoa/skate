# Cada vez que alguém (mentor ou administrador) abre o vídeo de outra pessoa.
# Serve para investigar um vazamento: quem viu, quando e de onde.
class ClipAccess < ApplicationRecord
  belongs_to :viewer, class_name: "User", optional: true # nil se a conta foi apagada
  belongs_to :training_session
end
