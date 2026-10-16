require "test_helper"

# Painel do super administrador (/painel): só a conta Google com e-mail em
# SUPER_ADMIN_EMAILS entra; remove contas, tira acesso de mentor, apaga vídeos e devolutivas.
class AdminPanelTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    @original_emails = Rails.configuration.x.flipaai.super_admin_emails
    Rails.configuration.x.flipaai.super_admin_emails = [ "dono@example.com" ]

    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "0.3", slug: "t-queda",
                                 name: "QUEDA CONTROLADA", position: 0, kind: :drill)
    @learner = password_account("aprendiz@example.com")
    @learner.choose_nickname(nickname: "Rato", tag: "0420")
    @mentor  = password_account("mentor@example.com").tap(&:role_mentor!)
  end

  teardown { Rails.configuration.x.flipaai.super_admin_emails = @original_emails }

  def password_account(contact)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      user.update!(birth_year: 2000, terms_accepted_at: Time.current)
    end
  end

  def sign_in_password(user) = post(session_path, params: { session: { contact: user.contact, password: PASSWORD } })
  def sign_in_owner = sign_up_with_google("dono@example.com", nickname: "dono")

  def clip_for(user, review: :pending)
    session = user.training_sessions.new(maneuver: @maneuver, scheduled_on: Date.current, status: :submitted,
                                         submitted_at: Time.current, outcome: :felt_safe,
                                         gear_checked: true, ground_clear: true, space_safe: true)
    session.clip.attach(io: File.open(file_fixture("manobra.mp4"), "rb"), filename: "manobra.mp4", content_type: "video/mp4")
    session.save!
    session.create_ai_review!(status: review)
    session
  end

  test "só a conta Google do dono entra no painel; para os outros ele não existe" do
    get admin_root_path
    assert_redirected_to root_path, "sem login"

    sign_in_password(@learner)
    get admin_root_path
    assert_response :not_found
    delete sign_out_path

    admin = password_account("admin@example.com").tap(&:role_admin!)
    sign_in_password(admin)
    get admin_users_path
    assert_response :not_found, "administrador comum não é super admin"
    delete sign_out_path

    impostor = password_account("dono@example.com")
    sign_in_password(impostor)
    get admin_root_path
    assert_response :not_found, "conta com senha e o mesmo e-mail não vale: só entrando pelo Google"
    delete sign_out_path
    impostor.destroy!

    owner = sign_in_owner
    assert owner.super_admin?
    assert owner.mentor_access? && owner.admin_access?
    get admin_root_path
    assert_response :success
    assert_select "a.icon-btn[href=?]", admin_root_path
    assert_select ".admin-stat", 6
  end

  test "remover uma conta apaga vídeos, devolutivas e chat dela" do
    video = clip_for(@learner, review: :completed)
    @learner.create_conversation!.messages.create!(author: @learner, body: "Oi, equipe!")
    sign_in_owner

    delete admin_user_path(@learner)
    assert_redirected_to admin_users_path
    assert_nil User.find_by(id: @learner.id)
    assert_nil TrainingSession.find_by(id: video.id)
    assert_equal 0, ActiveStorage::Attachment.where(record_type: "TrainingSession", record_id: video.id).count
    assert_equal 0, Conversation.where(learner_id: @learner.id).count
  end

  test "remover um administrador que aprovou mentores mantém os mentores" do
    admin = password_account("admin@example.com").tap(&:role_admin!)
    @mentor.approve_mentor!(by: admin)
    sign_in_owner

    delete admin_user_path(admin)
    assert_nil User.find_by(id: admin.id)
    assert @mentor.reload.role_mentor?
    assert_nil @mentor.mentor_approved_by_id
  end

  test "a conta do super administrador não sai pelo painel" do
    owner = sign_in_owner
    delete admin_user_path(owner)
    assert_redirected_to admin_users_path
    assert User.exists?(owner.id)
    patch demote_admin_user_path(owner)
    assert owner.reload.super_admin?
  end

  test "tirar o acesso de mentor volta a aprendiz e derruba as sessões" do
    token = @mentor.token
    sign_in_owner
    patch demote_admin_user_path(@mentor)
    assert_redirected_to admin_users_path
    assert @mentor.reload.role_learner?
    assert_not_equal token, @mentor.token
  end

  test "busca por nickname#0000, por parte do nickname e por e-mail" do
    password_account("outro@example.com").choose_nickname(nickname: "Rato", tag: "0999")
    sign_in_owner

    get admin_users_path(q: "rato#0420")
    assert_select ".admin-user", 1
    assert_select ".admin-user .auth-card-value", "Rato#0420"

    get admin_users_path(q: "rat")
    assert_select ".admin-user", 2

    get admin_users_path(q: "mentor@exa")
    assert_select ".admin-user", 1
    assert_select ".admin-user .auth-card-value", "mentor@example.com"
  end

  test "o dono vê e apaga qualquer vídeo, até de mentor" do
    learner_video = clip_for(@learner)
    mentor_video  = clip_for(@mentor)
    owner = sign_in_owner
    assert mentor_video.clip_visible_to?(owner)

    get admin_videos_path
    assert_select "##{ActionView::RecordIdentifier.dom_id(mentor_video, :admin)} video[preload=none]"

    delete admin_video_path(learner_video)
    assert_redirected_to admin_videos_path
    assert_not learner_video.reload.clip.attached?
    assert_nil learner_video.ai_review, "a devolutiva que nem foi escrita sai junto"
  end

  test "apagar a devolutiva tira o texto do aprendiz e devolve o vídeo para a fila" do
    video = clip_for(@learner)
    video.ai_review.answer(@mentor, headline: "", strengths: "Base firme.", mistake: "Olhou para baixo.", next_focus: "Olhar à frente.")
    assert_not TrainingSession.awaiting_review.exists?(video.id)
    sign_in_owner

    get admin_reviews_path
    assert_match "Olhou para baixo.", response.body

    delete admin_review_path(video.ai_review)
    assert_redirected_to admin_reviews_path
    review = video.ai_review.reload
    assert review.status_pending?
    assert_nil review.mistake
    assert_nil review.reviewer
    assert TrainingSession.awaiting_review.exists?(video.id)
    assert video.reload.status_submitted?
  end
end
