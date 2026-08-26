module Ai
  # Ponto único de integração com o modelo que analisa o vídeo do drill de queda.
  #
  # Hoje devolve uma análise determinística (placeholder) para o fluxo rodar
  # ponta a ponta. Troque #call pela chamada real ao provedor mantendo o mesmo
  # contrato de retorno.
  class FallAnalyzer
    Result = Struct.new(:headline, :strengths, :mistake, :next_focus, :raw, keyword_init: true)

    def initialize(training_session)
      @session = training_session
    end

    def call
      raise ArgumentError, "sessão sem vídeo" unless session.clip.attached?

      # TODO: enviar session.clip para o provedor de visão e mapear a resposta.
      Result.new(
        headline: "Análise do seu #{session.maneuver.name.downcase}",
        strengths: "Você encolheu os joelhos corretamente e manteve a base firme na aterrissagem.",
        mistake: "O ombro tocou o chão muito tenso, o que reduz o amortecimento.",
        next_focus: "Solte o ar e relaxe os ombros instantes antes de iniciar o rolamento.",
        raw: { provider: "stub", version: 0 }
      ).to_h
    end

    private

    attr_reader :session
  end
end
