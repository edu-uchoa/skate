module Admin
  # Início do painel: os números do app e os atalhos para cada lista.
  class DashboardsController < BaseController
    def show
      videos = TrainingSession.joins(:clip_attachment)
      @counts = {
        learners: User.registered.role_learner.count,
        mentors:  User.role_mentor.count,
        admins:   User.role_admin.count,
        videos:   videos.count,
        queue:    videos.awaiting_review.count,
        reviews:  AiReview.status_completed.count
      }
    end
  end
end
