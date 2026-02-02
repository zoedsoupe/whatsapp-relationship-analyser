defmodule WhatsAppAnalyzer.Keywords do
  @moduledoc """
  Keywords para análise de sentimentos em português brasileiro.
  Inclui expressões formais, informais e gírias.
  """

  # Indicadores românticos (expandido)
  @romantic [
    # Formais
    "amor",
    "amo",
    "amo você",
    "te amo",
    "amo vc",
    "meu amor",
    "minha vida",
    "querido",
    "querida",
    "saudade",
    "beijo",
    "beijinho",
    "apaixonado",
    "apaixonada",
    "namorar",
    "namorado",
    "namorada",
    "carinho",
    "sinto sua falta",
    "lindo",
    "linda",
    "tesão",
    "gostoso",
    "gostosa",
    "paixão",
    "amado",
    "amada",

    # Informais e gírias brasileiras
    "mozão",
    "mozinho",
    "bb",
    "bebe",
    "bebê",
    "neném",
    "s2",
    "<3",
    "gato",
    "gata",
    "gatinho",
    "gatinha",
    "delícia",
    "xuxu",
    "benzinho",
    "amore",
    "amorzão",
    "anjo",
    "docinho",
    "coração",
    "meu bem",
    "fofo",
    "fofa",
    "fofinho",
    "fofinha",

    # Abreviações comuns
    "sdds",
    "amo mt",
    "te amo mt",
    "amo d+",
    "amo dmais",
    "amo mto",
    "mt amor",
    "mto amor"
  ]

  # Planejamento futuro
  @future_planning [
    # Curto prazo
    "planejar",
    "planejando",
    "planos",
    "amanhã",
    "semana que vem",
    "próxima semana",
    "próximo fim de semana",
    "fim de semana",
    "feriado",
    "férias",

    # Longo prazo
    "futuro",
    "nosso futuro",
    "morar",
    "juntos",
    "juntas",
    "casa",
    "nossa casa",
    "viajar",
    "viagem",
    "casar",
    "casamento",
    "noivo",
    "noiva",
    "filhos",
    "família",
    "nossa família"
  ]

  # Intimidade e conexão emocional
  @intimacy [
    # Emoções
    "sinto",
    "sentir",
    "sentimento",
    "sentimentos",
    "emoção",
    "emoções",
    "emocional",

    # Confiança
    "confiar",
    "confio",
    "confiança",
    "confio em você",
    "confio em vc",

    # Vulnerabilidade
    "segredo",
    "pessoal",
    "íntimo",
    "íntima",
    "intimidade",
    "vulnerável",
    "abrir",
    "abrir o coração",
    "me abrir",
    "coração",
    "alma",

    # Conexão
    "confesso",
    "contar",
    "dividir",
    "compartilhar",
    "entendo você",
    "te entendo",
    "entendo vc",
    "apoiar",
    "apoio",
    "sempre aqui",
    "pode contar",
    "estou aqui",
    "conte comigo"
  ]

  # API pública
  @spec romantic() :: [String.t()]
  def romantic, do: @romantic

  @spec future_planning() :: [String.t()]
  def future_planning, do: @future_planning

  @spec intimacy() :: [String.t()]
  def intimacy, do: @intimacy

  @spec all() :: %{romantic: [String.t()], intimacy: [String.t()], future_planning: [String.t()]}
  def all do
    %{
      romantic: @romantic,
      intimacy: @intimacy,
      future_planning: @future_planning
    }
  end
end
