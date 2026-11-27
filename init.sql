-- Noticias recogidas de los feeds RSS. La URL es única: una noticia se guarda una sola vez.
CREATE TABLE IF NOT EXISTS raw_news (
    id           SERIAL PRIMARY KEY,
    title        TEXT NOT NULL,
    url          TEXT NOT NULL UNIQUE,
    source       TEXT NOT NULL,
    raw_content  TEXT,
    published_at TIMESTAMPTZ NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_raw_news_published_at ON raw_news (published_at DESC);

-- Resúmenes enviados a Telegram: el HTML tal cual se envió, el modelo que lo redactó
-- y las noticias que la validación descartó (con el motivo).
CREATE TABLE IF NOT EXISTS digests (
    id           SERIAL PRIMARY KEY,
    digest_type  VARCHAR(20) NOT NULL,
    content_html TEXT NOT NULL,
    model        TEXT NOT NULL,
    news_count   INTEGER NOT NULL,
    discarded    JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
