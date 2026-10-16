module ApplicationHelper
  # Menu de baixo: só depois do onboarding, a partir da trilha. Antes disso (logo,
  # login, nickname, idade, perguntas e plano) a pessoa segue pelos botões da tela.
  def show_bottom_nav?
    return false if !signed_in? || controller_path.start_with?("onboarding/")
    current_user.onboarded? || current_user.mentor_access?
  end

  # Vídeo de treino: sempre pelo endereço protegido (/videos/:id) e sem os botões de
  # baixar e de janela flutuante. Isso dificulta, mas não impede gravar a tela.
  def training_video_tag(training_session, **options)
    tag.video(src: "#{clip_path(training_session)}#t=0.1", controls: true, playsinline: true, preload: "metadata",
              controlslist: "nodownload", disablepictureinpicture: true, oncontextmenu: "return false;", **options)
  end
end
