module ApplicationHelper
  # Bolinha com o número em cima de um ícone do menu (some quando é zero).
  def nav_badge(count, label)
    return if count.to_i.zero?
    tag.span(count > 99 ? "99+" : count, class: "nav-badge", aria: { label: "#{count} #{label}" })
  end

  # Aprendiz: devolutivas que o mentor mandou e ele ainda não abriu (número no ícone Zine).
  def new_reviews_count
    @new_reviews_count ||= AiReview.unseen.joins(:training_session).where(training_sessions: { user_id: current_user.id }).count
  end
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
