module AdminHelper
  ROLE_LABELS = { "learner" => "Aprendiz", "mentor" => "Mentor", "admin" => "Administrador" }.freeze

  def admin_role_label(user) = user.super_admin? ? "Super administrador" : ROLE_LABELS.fetch(user.role)

  # O super administrador vê o contato completo (é o dono do app); o nickname#0000 vem antes.
  def admin_user_name(user) = user.handle || user.contact

  def admin_time(time) = time&.in_time_zone(current_user.time_zone)&.strftime("%d/%m/%Y às %H:%M")
end
