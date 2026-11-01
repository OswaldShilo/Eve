# Local Appwrite

Self-hosted Appwrite 2.6.2 for development. Install with the `docker run ... --entrypoint="install" appwrite/appwrite:2.6.2`
command in `plans/03-tech-stack.md` Task 1, from this directory. Stop with `docker compose -f appwrite/docker-compose.yml down`,
start again with `docker compose -f appwrite/docker-compose.yml up -d`.

Project ID: `eve-local`. Console: http://localhost/console. API endpoint: http://localhost/v1
(Android emulator: http://10.0.2.2/v1, physical device: http://<your LAN IP>/v1).
