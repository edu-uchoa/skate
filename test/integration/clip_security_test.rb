require "test_helper"

class ClipSecurityTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    @maneuver = Maneuver.create!(learning_module: learning_module, code: "0.3", slug: "t-queda",
                                 name: "QUEDA CONTROLADA", position: 0, kind: :drill)
    @owner    = account("dono@example.com")
    @stranger = account("outro@example.com")
    @mentor   = account("mentor@example.com").tap(&:role_mentor!)
    @admin    = account("admin@example.com").tap(&:role_admin!)
    @clip     = clip_for(@owner)
    @bytes    = File.binread(file_fixture("manobra.mp4"))
  end

  def account(contact)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      user.update!(birth_year: 1995, terms_accepted_at: Time.current)
    end
  end

  def clip_for(user)
    session = user.training_sessions.new(maneuver: @maneuver, scheduled_on: Date.current, status: :submitted,
                                         submitted_at: Time.current, gear_checked: true, ground_clear: true, space_safe: true)
    session.clip.attach(io: File.open(file_fixture("manobra.mp4"), "rb"), filename: "rolê da maria.mp4", content_type: "video/mp4")
    session.save!
    session.create_ai_review!(status: :pending)
    session
  end

  def sign_in(user) = post session_path, params: { session: { contact: user.contact, password: PASSWORD } }

  test "sem login o vídeo não abre" do
    get clip_path(@clip)
    assert_redirected_to new_session_path
  end

  test "os links públicos do Active Storage não existem mais" do
    signed_id = @clip.clip.blob.signed_id
    get "/rails/active_storage/blobs/redirect/#{signed_id}/manobra.mp4"
    assert_response :not_found
  end

  test "o dono assiste, inteiro ou em pedaços, sem cache e sem o nome original do arquivo" do
    sign_in(@owner)

    get clip_path(@clip)
    assert_response :success
    assert_equal @bytes, response.body
    assert_equal "video/mp4", response.media_type
    assert_match "no-store", response.headers["Cache-Control"]
    assert_match "video.mp4", response.headers["Content-Disposition"]
    assert_no_match "maria", response.headers["Content-Disposition"]

    get clip_path(@clip), headers: { "Range" => "bytes=0-3" }
    assert_response :partial_content
    assert_equal @bytes[0, 4], response.body
    assert_equal 0, ClipAccess.count, "o dono vendo o próprio vídeo não é registrado"
  end

  test "outro aprendiz não vê o vídeo" do
    sign_in(@stranger)
    get clip_path(@clip)
    assert_response :not_found
  end

  test "mentor e administrador veem vídeo de aprendiz e o acesso fica registrado" do
    [ @mentor, @admin ].each do |viewer|
      sign_in(viewer)
      get clip_path(@clip)
      assert_response :success
      get clip_path(@clip), headers: { "Range" => "bytes=4-9" }
      delete sign_out_path
    end

    assert_equal [ @mentor, @admin ], ClipAccess.order(:id).map(&:viewer), "um registro por pessoa, não por pedaço"
    assert_equal @clip, ClipAccess.last.training_session
  end

  test "mentor não vê vídeo de outro mentor" do
    other_clip = clip_for(@admin)
    sign_in(@mentor)
    get clip_path(other_clip)
    assert_response :not_found
  end

  test "os players do app usam o endereço protegido e sem botão de download" do
    sign_in(@owner)
    get zine_path

    assert_select "video[src^=?][controlslist=nodownload]", clip_path(@clip)
    assert_no_match "/rails/active_storage", response.body
  end
end
