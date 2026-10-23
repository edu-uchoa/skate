require "test_helper"

# Perfil do aprendiz na área do mentor (abre pelo nome, no chat): respostas das 3
# perguntas do cadastro, nível, ofensiva, trilha e as observações da equipe de mentores.
class LearnerProfileTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    learning_module = LearningModule.create!(code: "0", name: "BASE", position: 0)
    @setup_step = Maneuver.create!(learning_module: learning_module, code: "0.1", slug: "t-setup", name: "SETUP", position: 0, kind: :drill, description: "Monte o skate.")
    Maneuver.create!(learning_module: learning_module, code: "0.2", slug: "t-ollie", name: "OLLIE", position: 1, prerequisite: @setup_step, description: "O primeiro pulo.")

    @learner = account("aprendiz@example.com", nickname: "Rato")
    diagnosis = @learner.create_diagnosis!(level: :stuck_on_ollie, setup: :store_board, completed_at: Time.current)
    diagnosis.diagnosis_blockers.create!([ { kind: :fear_of_falling }, { kind: :shame } ])
    progression = TrackProgression.new(@learner)
    progression.sync!
    progression.complete!(@setup_step)

    @ana  = account("ana@example.com", nickname: "Ana", role: :mentor)
    @beto = account("beto@example.com", nickname: "Beto", role: :mentor)
  end

  def account(contact, nickname:, role: :learner)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      user.update!(birth_year: 1995, terms_accepted_at: Time.current, role: role)
      user.choose_nickname(nickname: nickname)
    end
  end

  def sign_in(user)
    delete sign_out_path # troca de conta no meio do teste
    post session_path, params: { session: { contact: user.contact, password: PASSWORD } }
  end

  test "no chat, tocar no nome do aprendiz abre o perfil dele" do
    sign_in(@ana)
    get mentor_chat_path(@learner)
    assert_select "a.mentor-learner-head.is-link[href=?]", mentor_learner_path(@learner), /Rato/
  end

  test "o perfil mostra as respostas do cadastro, o nível, a ofensiva e onde ele está na trilha" do
    sign_in(@ana)
    get mentor_learner_path(@learner)
    assert_response :success

    assert_select ".learner-answers" do
      assert_select "dt", "Qual é o seu nível hoje?"
      assert_select "dd", "Estou travado tentando o Ollie"
      assert_select "dd", "Medo de cair e me machucar · Vergonha de treinar na frente dos outros"
      assert_select "dd", "Skate montado comum"
    end
    assert_select ".profile-stat", /Nível 1\s*50 XP/
    assert_select ".profile-stat.is-streak", /0 sessões/
    assert_select ".profile-stat", /0\.2 · OLLIE\s*Na trilha agora · BASE/
    assert_select ".profile-stat.is-tasks", /1 de 2/
    assert_select "a[href=?]", mentor_chat_path(@learner)
  end

  test "aprendiz que ainda não respondeu as perguntas" do
    @learner.diagnosis.destroy!
    sign_in(@ana)
    get mentor_learner_path(@learner)
    assert_select ".learner-answers", /Ainda não respondeu as perguntas do cadastro/
  end

  test "observações: o mentor escreve, a equipe de mentores lê e o aprendiz não vê" do
    note = "Na próxima aula, treinar a base do ollie parado, na grama."
    sign_in(@ana)
    post mentor_learner_notes_path(@learner), params: { mentor_note: { body: note } }
    assert_redirected_to mentor_learner_path(@learner, anchor: "observacoes")
    assert_equal [ @ana ], @learner.mentor_notes.map(&:author)

    post mentor_learner_notes_path(@learner), params: { mentor_note: { body: "Manda no zap 61 99999-0000" } }
    assert_match "não escreva telefone", flash[:alert]
    post mentor_learner_notes_path(@learner), params: { mentor_note: { body: "  " } }
    assert_match "Escreva a observação.", flash[:alert]
    assert_equal 1, @learner.mentor_notes.count

    sign_in(@beto)
    get mentor_learner_path(@learner)
    assert_select ".learner-note", /Ana.*#{Regexp.escape(note)}/m
    assert_select ".learner-note .learner-note-delete", 0, "só quem escreveu (ou a administração) apaga"

    sign_in(@learner)
    get mentor_learner_path(@learner)
    assert_response :not_found
    [ my_account_path, zine_path, chat_path, track_path ].each do |path|
      get path
      assert_no_match note, response.body, path
    end
  end

  test "apaga a observação quem escreveu ou a administração" do
    note = @learner.mentor_notes.create!(author: @ana, body: "Treinar a queda.")
    other = @learner.mentor_notes.create!(author: @ana, body: "Postura boa.")

    sign_in(@beto)
    delete mentor_learner_note_path(@learner, note)
    assert_response :not_found
    assert MentorNote.exists?(note.id)

    sign_in(@ana)
    delete mentor_learner_note_path(@learner, note)
    assert_redirected_to mentor_learner_path(@learner, anchor: "observacoes")
    assert_not MentorNote.exists?(note.id)

    sign_in(account("admin@example.com", nickname: "Admin", role: :admin))
    delete mentor_learner_note_path(@learner, other)
    assert_not MentorNote.exists?(other.id)
  end

  test "só existe perfil de aprendiz, e só mentores abrem" do
    sign_in(@ana)
    get mentor_learner_path(@beto)
    assert_response :not_found
    post mentor_learner_notes_path(@beto), params: { mentor_note: { body: "Oi" } }
    assert_response :not_found
  end

  test "Meus dados traz as observações; apagar a conta do aprendiz leva junto, a do mentor não" do
    @learner.mentor_notes.create!(author: @ana, body: "Treinar a queda.")
    data = DataExport.new(@learner, clip_url: ->(_) { "" }).as_json
    assert_equal [ "Treinar a queda." ], data[:observacoes_dos_mentores].map { it[:texto] }
    assert_equal "equipe de mentores", data[:observacoes_dos_mentores].first[:de]
    assert_equal 1, DataExport.new(@ana, clip_url: ->(_) { "" }).as_json[:observacoes_que_voce_escreveu]

    @ana.destroy!
    assert_nil MentorNote.last.author, "a observação fica, sem o autor"
    @learner.destroy!
    assert_equal 0, MentorNote.count
  end
end
