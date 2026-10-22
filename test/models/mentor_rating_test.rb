require "test_helper"

# Média de rolamentos do mentor (MentorRating) e a avaliação do aprendiz (AiReview#rate).
class MentorRatingTest < ActiveSupport::TestCase
  ANSWER = { headline: "", strengths: "Bem.", mistake: "Braço.", next_focus: "Ombro." }.freeze

  setup do
    @maneuver = Maneuver.create!(learning_module: LearningModule.create!(code: "0", name: "BASE", position: 0),
                                 code: "0.3", slug: "t-queda", name: "QUEDA", position: 0, kind: :drill)
    @mentor = user("mentor@example.com", role: :mentor)
  end

  def user(contact, role: :learner)
    User.register(contact: contact, password: "manobra123", password_confirmation: "manobra123").tap { it.update!(role: role) }
  end

  def answered_review(learner, mentor = @mentor)
    session = learner.training_sessions.create!(maneuver: @maneuver, scheduled_on: Date.current)
    session.create_ai_review!(status: :pending).tap { it.answer(mentor, **ANSWER) }
  end

  test "média por aluno: quem avalia muitas vezes não pesa mais" do
    fan = user("fa@example.com")
    3.times { answered_review(fan).rate(10) }
    answered_review(user("outro@example.com")).rate(4)

    score = MentorRating.of(@mentor)
    assert_equal 7.0, score.average, "(10 + 4) / 2, e não (10 + 10 + 10 + 4) / 4"
    assert_equal 2, score.learners
  end

  test "mentor sem avaliação não tem média e vai para o fim da lista" do
    rated = user("bom@example.com", role: :mentor)
    answered_review(user("a@example.com"), rated).rate(9)

    scores = MentorRating.for([ @mentor, rated ])
    assert_nil scores[@mentor.id]
    assert_equal [ rated, @mentor ], MentorRating.ranked([ @mentor, rated ], scores)
  end

  test "a avaliação é de 1 a 10, uma vez, só em devolutiva de mentor, e a mensagem é opcional" do
    review = answered_review(user("a@example.com"))
    assert_not review.rate(0)
    assert_not review.rate("dez")
    assert review.rate("10")
    assert_nil review.rating_comment
    assert_not review.rate(5)
    assert_equal [ "Essa devolutiva já foi avaliada." ], review.errors.full_messages

    pending = user("b@example.com").training_sessions.create!(maneuver: @maneuver, scheduled_on: Date.current)
                                   .create_ai_review!(status: :pending)
    assert_not pending.rate(8), "ainda sem devolutiva"
  end

  test "devolutiva apagada pelo super admin sai da média" do
    review = answered_review(user("a@example.com"))
    review.rate(2)
    review.retract!

    assert_nil review.reload.rating
    assert_nil MentorRating.of(@mentor)
  end

  test "resumo do mentor: até 300 caracteres e sem contato de fora do app" do
    assert_not @mentor.update(mentor_bio: "x" * 301)
    [ "Zap 61 99999-0000", "ana@gmail.com", "veja www.ana.com", "sigam @ana.skate" ].each do |bio|
      assert_not @mentor.update(mentor_bio: bio), bio
    end
    assert @mentor.update(mentor_bio: "  Street há 10 anos.  ")
    assert_equal "Street há 10 anos.", @mentor.reload.mentor_bio
  end
end
