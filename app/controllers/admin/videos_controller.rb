module Admin
  # Todos os vídeos do app (de aprendizes, mentores e administradores), do mais novo
  # para o mais antigo, para assistir e apagar.
  class VideosController < BaseController
    def index
      @videos = TrainingSession.with_clip.includes(:user).order(id: :desc).limit(LIMIT)
    end

    def destroy
      video = TrainingSession.with_clip.find(params[:id])
      video.remove_clip!
      audit("apagou o vídeo do treino #{video.id} (conta #{video.user_id})")
      redirect_to admin_videos_path, notice: "Vídeo apagado. Ninguém mais consegue ver."
    end
  end
end
