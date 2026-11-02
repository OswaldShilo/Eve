# Local Appwrite

Self-hosted Appwrite 2.6.2 for development. Install with the `docker run ... --entrypoint="install" appwrite/appwrite:2.6.2`
command in `plans/03-tech-stack.md` Task 1, from this directory. Stop with `docker compose -f appwrite/docker-compose.yml down`,
start again with `docker compose -f appwrite/docker-compose.yml up -d`.

Project ID: `eve-local`. Console: http://localhost/console. API endpoint: http://localhost/v1
(Android emulator: http://10.0.2.2/v1, physical device: http://<your LAN IP>/v1).

Windows notes (see plans/03-tech-stack.md Task 1): `appwrite/.env` must contain `_APP_MQTT_PORT=18883`
(8883 is a Windows-reserved port), and the project needs the global variable
`EVE_API_ENDPOINT=http://host.docker.internal/v1` so functions can reach the API.
Local credentials (console login, CLI API key) are in `appwrite/eve-local.secrets` (gitignored).
