# Aviso de devolutiva nova para o aprendiz (número no ícone Zine): seen_at guarda
# quando ele abriu a devolutiva. Enquanto estiver vazio (ou se o mentor revisar
# depois), a devolutiva conta como nova.
class AddSeenAtToAiReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_reviews, :seen_at, :datetime

    # As devolutivas de antes do aviso contam como vistas: ninguém recebe um monte de
    # "novas" antigas de uma vez.
    up_only do
      execute "UPDATE ai_reviews SET seen_at = COALESCE(revised_at, completed_at, updated_at) WHERE status = 2"
    end
  end
end
