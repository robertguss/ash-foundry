# AshFoundry

AshFoundry generates production-oriented, Ash-first Phoenix applications. It
composes the official `phx.new`, Ash, AshPostgres, and AshPhoenix installers,
then adds an application-owned PostgreSQL/Inertia/React foundation with local
quality and deployment tooling.

Version 0.1.0 is pre-release software.

## Package model

AshFoundry deliberately has two small distribution units:

- `ash_foundry_new` is a thin Mix archive that provides
  `mix ash_foundry.new APP_NAME`, validates the wizard input, and bootstraps a
  new application.
- `ash_foundry` is the Igniter package containing the normalized generation
  plan, recipe installer, and templates.

Generated source belongs to the generated application. AshFoundry records its
secret-free generation plan in `.ash_foundry.exs`; v1 does not attempt automatic
starter upgrades.

## Prerequisites

- mise
- Docker with the Compose plugin
- Git

The generated toolchain is pinned to Erlang/OTP 29.0.5, Elixir 1.20.4, Node.js
24.20.0 LTS, and pnpm 11.24.0. The bootstrap command also requires these exact
archives:

```bash
mix archive.install hex phx_new 1.8.13 --force
mix archive.install hex igniter_new 0.5.34 --force
```

## Installation

After `ash_foundry_new` is published to Hex, install it with:

```bash
mix archive.install hex ash_foundry_new 0.1.0 --force
```

To use this repository before publication:

```bash
mise install
mise run setup
mise exec -- mix cmd --cd installer mix archive.build
mix archive.install installer/ash_foundry_new-0.1.0.ez --force
export ASH_FOUNDRY_PATH="$PWD"
```

`ASH_FOUNDRY_PATH` makes the archive install the local `ash_foundry` package.
Without it, the archive resolves `ash_foundry` version 0.1.0 from Hex.

## Generate an application

The interactive form displays defaults and prints the complete equivalent
command before it writes anything:

```bash
mix ash_foundry.new my_app
```

For deterministic generation, provide the complete selection and `--yes`:

```bash
mix ash_foundry.new my_app \
  --recipe saas \
  --auth google,password \
  --registration open \
  --tenancy organizations \
  --deploy fly \
  --no-google-hosted-domain \
  --yes
```

Supported options:

- `--recipe internal|saas|personal|custom`
- `--auth google,password,magic-link|none` (a comma-separated subset)
- `--registration open|invite-only|closed`
- `--tenancy none|organizations`
- `--deploy render|fly|none`
- `--google-hosted-domain` or `--no-google-hosted-domain`
- `--module MyApp`
- `--yes`

No-auth applications are available through `custom`; they must use closed
registration and no tenancy. The generator validates incompatible combinations
before applying the AshFoundry installer.

## Recipes

Recipes are overridable bundles, not separate starters:

| Recipe     | Authentication        | Registration | Tenancy       |
| ---------- | --------------------- | ------------ | ------------- |
| `internal` | Google                | Invite-only  | None          |
| `saas`     | Google + password     | Open         | Organizations |
| `personal` | Password + magic link | Open         | None          |
| `custom`   | Explicit              | Explicit     | Explicit      |

Deployment is always an explicit Render, Fly.io, or none selection. Only the
selected provider's manifest and runbook are generated.

## Generated architecture

Every recipe starts with:

- Phoenix 1.8, Ash 3, AshPostgres, PostgreSQL 18, and committed resource
  snapshots/migrations
- Inertia, React 19, strict TypeScript, Mantine 9, CSS Modules, Vite, and pnpm
- mise tasks and Docker Compose for PostgreSQL and Mailpit
- Oban in the combined web/worker release topology
- Swoosh with local Mailpit and credential-gated Resend delivery/webhooks
- aggregate-only first-party analytics, append-oriented audit evidence,
  authenticated feedback, and retention workers
- JSON logs, Sentry integration, telemetry, token-protected Prometheus metrics,
  and separate liveness/readiness probes
- browser security headers, CSRF and cross-site request protections, persisted
  revocable sessions, and rate limiting
- development-only Tidewave, mailbox, and personas
- opt-in Renovate configuration without external automation

Authentication recipes add persisted AshAuthentication tokens, provider identity
linking, system-administrator bootstrap invitations, registration policy
enforcement, account settings, and administrator screens. Organization tenancy
adds immutable URL slugs, owner/admin/member roles, tenant switching,
database-constrained relationships, and policy isolation tests.

Render and Fly.io outputs share a non-root multi-stage OCI image, Phoenix
release, explicit release migration command, graceful shutdown, and runtime-only
secrets. Fly keeps the combined web/Oban machine running rather than scaling it
to zero.

## Generated application workflow

In a generated application:

```bash
mise install
mise run setup
mise run dev
mise run check
```

`mise run check` includes Elixir formatting, warnings-as-errors compilation,
ExUnit, Ash migration drift, Credo, Sobelow, retired/dependency audits,
Dialyzer, TypeScript/Biome, Vitest and accessibility assertions, a Vite
production build, pnpm audit, Chromium Playwright smoke tests, and a production
release build.

No CI workflow is generated. AshFoundry also does not initialize Git, create a
remote repository, publish packages, deploy, or enable Renovate.

## Provider verification boundary

Generation and local verification require no external-provider credentials.
Resend, Google OAuth, Sentry, Render, and Fly.io remain disabled until the
generated runbook's runtime variables are configured. Real OAuth redirects,
email delivery/webhooks, hosted error ingestion, provider-native deployment,
private-network metrics scraping, and DNS/TLS therefore require provider
accounts and cannot be proven by the credential-free local gate.

## Development

The repository's own toolchain is pinned in `mise.toml`:

```bash
mise install
mise run setup
mise run check
```

The acceptance matrix builds both packages and exercises all four recipes plus
critical overrides in temporary directories. See the durable
[product and architecture decisions](docs/product-and-architecture-decisions.md)
for confirmed behavior, exclusions, and implementation evidence.

## License

MIT. See [LICENSE](LICENSE).
