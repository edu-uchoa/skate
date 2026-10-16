module Ai
  # Ponto único de integração com a análise automática do vídeo do drill de queda
  # (IA ou reconhecimento corporal, decisão em aberto da equipe).
  #
  # Ainda não existe análise real: hoje o vídeo vai para a fila do mentor e este
  # código só roda com config.x.flipaai.automatic_review ligado. Ao implementar,
  # devolva um Result com headline, strengths (o que fez bem), mistake (onde foi o
  # erro), next_focus (foco da próxima sessão) e raw (resposta bruta do provedor).
  class FallAnalyzer
    NotConfigured = Class.new(StandardError)

    Result = Struct.new(:headline, :strengths, :mistake, :next_focus, :raw, keyword_init: true)

    def initialize(training_session)
      @session = training_session
    end

    def call
      raise ArgumentError, "sessão sem vídeo" unless session.clip.attached?

      # Nunca devolva uma análise de exemplo: a pessoa acharia que o vídeo dela foi visto.
      raise NotConfigured, "Análise automática ainda não implementada; o vídeo segue para o mentor."
    end

    private

    attr_reader :session
  end
end
