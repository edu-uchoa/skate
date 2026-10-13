require "test_helper"

class MessageTest < ActiveSupport::TestCase
  setup do
    learner = User.register(contact: "aprendiz@example.com", password: "manobra123", password_confirmation: "manobra123")
    @conversation = Conversation.for(learner)
  end

  def message(body) = @conversation.messages.build(author: @conversation.learner, body: body)

  test "frases normais de treino passam pelo filtro de contato" do
    [ "Caí 3 vezes no ollie, mas na 4ª saiu!", "Meu shape tem 8.25 e as rodas 52mm.",
      "Amanhã às 15h30 eu ando de novo, dia 14/10.", "Valeu, mentor! Bora." ].each do |text|
      assert message(text).valid?, text
    end
  end

  test "contato de fora do app, mensagem vazia ou longa demais não entram" do
    [ "61 99999-0000", "(61) 3333 4444", "eu@email.com", "https://site.com", "vem no insta @skate.df", " ", "a" * 1001 ].each do |text|
      assert_not message(text).valid?, text
    end
  end
end
