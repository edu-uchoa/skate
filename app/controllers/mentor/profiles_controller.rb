module Mentor
  # Resumo profissional do mentor (no Perfil), que os aprendizes leem na hora de escolher
  # quem avalia o vídeo.
  class ProfilesController < BaseController
    def update
      bio = params.dig(:mentor_profile, :bio)
      if current_user.update(mentor_bio: bio)
        redirect_to my_account_path(anchor: "mentor"), notice: "Resumo salvo. Os aprendizes já veem o texto novo."
      else
        flash[:mentor_bio] = bio.to_s.first(User::MENTOR_BIO_LENGTH * 2) # volta o que foi escrito, para corrigir
        redirect_to my_account_path(anchor: "mentor"), alert: current_user.errors.full_messages.to_sentence
      end
    end
  end
end
