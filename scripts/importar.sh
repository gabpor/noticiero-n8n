#!/usr/bin/env bash
# Crea las credenciales en n8n a partir de .env e importa los dos workflows.
# Uso (con el stack levantado):  bash scripts/importar.sh
# Las claves pasan del .env al contenedor como variables de entorno, n8n las guarda
# cifradas y el archivo temporal se borra. Los workflows solo llevan el id de la credencial.
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash en Windows: no reescribir rutas del contenedor

cd "$(dirname "$0")/.."
[ -f .env ] || { echo "Falta .env (copia .env.example y rellénalo)"; exit 1; }
set -a; . ./.env; set +a
for v in POSTGRES_PASSWORD GEMINI_API_KEY GROQ_API_KEY TELEGRAM_BOT_TOKEN; do
  [ -n "${!v:-}" ] || { echo "Falta $v en .env"; exit 1; }
done

# Esperar a que n8n termine sus migraciones: si el CLI entra antes, chocan.
echo "Esperando a que n8n esté listo..."
for _ in $(seq 1 60); do
  curl -sf http://localhost:5679/healthz/readiness >/dev/null && break
  sleep 2
done
curl -sf http://localhost:5679/healthz/readiness >/dev/null || { echo "n8n no responde en localhost:5679"; exit 1; }

docker compose exec -T \
  -e POSTGRES_PASSWORD -e GEMINI_API_KEY -e GROQ_API_KEY -e TELEGRAM_BOT_TOKEN \
  n8n sh -c '
    umask 077
    node -e "
      const e = process.env;
      const creds = [
        { id: \"NtcPostgres00001\", name: \"Postgres noticiero\", type: \"postgres\",
          data: { host: \"postgres\", port: 5432, database: \"noticiero\", user: \"noticiero\", password: e.POSTGRES_PASSWORD, ssl: \"disable\" } },
        { id: \"NtcGemini0000001\", name: \"Gemini API\", type: \"httpHeaderAuth\",
          data: { name: \"x-goog-api-key\", value: e.GEMINI_API_KEY } },
        { id: \"NtcGroq000000001\", name: \"Groq API\", type: \"httpHeaderAuth\",
          data: { name: \"Authorization\", value: \"Bearer \" + e.GROQ_API_KEY } },
        { id: \"NtcTelegram00001\", name: \"Telegram bot\", type: \"telegramApi\",
          data: { accessToken: e.TELEGRAM_BOT_TOKEN, baseUrl: \"https://api.telegram.org\" } },
      ];
      require(\"fs\").writeFileSync(\"/tmp/credenciales.json\", JSON.stringify(creds));
    "
    n8n import:credentials --input=/tmp/credenciales.json
    status=$?
    rm -f /tmp/credenciales.json
    exit $status
  '

docker compose exec -T n8n n8n import:workflow --input=/files/ingesta.json
docker compose exec -T n8n n8n import:workflow --input=/files/resumen.json

echo "Listo: abre http://localhost:5679, edita el canal en el nodo «Configuración» del resumen y ejecuta primero la ingesta."
