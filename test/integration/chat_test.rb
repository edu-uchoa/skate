require "test_helper"

class ChatTest < ActionDispatch::IntegrationTest
  PASSWORD = "manobra123"

  setup do
    @learner = account("aprendiz@example.com", birth_year: Date.current.year - 15)
    @other   = account("outra@example.com", birth_year: 2000)
    @mentor  = account("mentor@example.com", birth_year: 1990).tap(&:role_mentor!)
    @admin   = account("admin@example.com", birth_year: 1985).tap(&:role_admin!)
  end

  def account(contact, birth_year:)
    User.register(contact: contact, password: PASSWORD, password_confirmation: PASSWORD).tap do |user|
      user.update!(birth_year: birth_year, terms_accepted_at: Time.current)
    end
  end

  def sign_in(user) = post session_path, params: { session: { contact: user.contact, password: PASSWORD } }
  def say(body, to: chat_messages_path) = post(to, params: { message: { body: body } }, as: :turbo_stream)

  test "o aprendiz fala com a equipe e o mentor responde pela área do mentor" do
    sign_in(@learner)
    get chat_path
    assert_response :success
    assert_select "#chat-empty", /Nenhuma mensagem ainda/
    say "Como eu sei se o shape é do tamanho certo?"
    assert_response :success
    assert_match "Como eu sei se o shape", response.body
    delete sign_out_path

    sign_in(@mentor)
    get mentor_chats_path
    assert_select ".guide-tab.is-active", /Chat \(1\)/
    assert_select "a.chat-list-item.is-unread[href=?]", mentor_chat_path(@learner) do
      assert_select "strong", /ap•••@example.com/
      assert_select ".guide-tag", "Menor"
      assert_select "small", /Como eu sei se o shape/
    end

    get mentor_chat_path(@learner)
    assert_select ".chat-bubble.is-theirs .chat-author", "Aprendiz"
    assert_select ".guide-tag", "Menor de idade"
    say "Fica de pé em cima dele: os pés têm que caber nos parafusos.", to: mentor_chat_messages_path(@learner)
    assert_response :success
    get mentor_chats_path
    assert_select ".guide-tab.is-active", /Chat \(0\)/, "abrir a conversa marca como lida"
    delete sign_out_path

    # Outro mentor vê a mesma conversa: ela é da equipe (o que a equipe escreveu fica à direita).
    sign_in(@admin)
    get mentor_chat_path(@learner)
    assert_select ".chat-bubble.is-mine .chat-author", "Mentor"
    assert_select ".chat-bubble.is-theirs .chat-author", "Aprendiz"
    delete sign_out_path

    sign_in(@learner)
    get zine_path
    assert_select "a.zine-chat-link.is-unread[href=?]", chat_path
    get chat_path
    assert_select ".chat-bubble.is-mine .chat-author", "Você"
    assert_select ".chat-bubble.is-theirs .chat-author", "Mentor"
    get zine_path
    assert_select "a.zine-chat-link.is-unread", 0
  end

  test "a conversa busca só as mensagens novas" do
    conversation = Conversation.for(@learner)
    first = conversation.post!(@learner, "Oi!")
    sign_in(@mentor)

    get mentor_chat_path(@learner, depois: first.id), as: :turbo_stream
    assert_response :no_content

    reply = conversation.post!(@admin, "Fala! Como foi o rolê?")
    get mentor_chat_path(@learner, depois: first.id), as: :turbo_stream
    assert_response :success
    assert_match ActionView::RecordIdentifier.dom_id(reply), response.body
    assert_no_match ActionView::RecordIdentifier.dom_id(first), response.body
  end

  test "telefone, e-mail, link e @ de rede social não entram no chat" do
    sign_in(@learner)
    [ "me chama no 61 99999-0000", "manda no meu@email.com", "olha www.site.com", "segue @skatista.df" ].each do |text|
      say text
      assert_response :unprocessable_entity, text
      assert_match "Por segurança", response.body
      assert_match CGI.escapeHTML(text), response.body, "o texto volta para a pessoa corrigir"
    end
    assert_nil @learner.reload.conversation&.messages&.first
  end

  test "cada um só vê o próprio chat; mentor não conversa com mentor" do
    Conversation.for(@learner).post!(@learner, "Mensagem só minha")

    sign_in(@other)
    get chat_path
    assert_no_match "Mensagem só minha", response.body
    get mentor_chats_path
    assert_response :not_found
    get mentor_chat_path(@learner)
    assert_response :not_found
    post mentor_chat_messages_path(@learner), params: { message: { body: "oi" } }
    assert_response :not_found
    delete sign_out_path

    sign_in(@mentor)
    get chat_path
    assert_redirected_to mentor_chats_path
    get mentor_chat_path(@admin)
    assert_response :not_found
  end

  test "sem login vai para o login" do
    get chat_path
    assert_redirected_to new_session_path
    get mentor_chats_path
    assert_redirected_to new_session_path
  end
end
