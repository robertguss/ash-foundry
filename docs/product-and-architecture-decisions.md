# AshFoundry Product and Architecture Decisions

Status: working specification Last consolidated: 2026-08-30 Source conversation:
https://ampcode.com/threads/T-01a0500b-b5a3-77fd-92b1-c84d2a76494b

This document is the durable source of truth for decisions made while designing
AshFoundry. It distinguishes confirmed decisions from implementation details
that still need to be settled. When this document and earlier discussion
conflict, the latest confirmed decision recorded here wins.

## 1. Product definition

AshFoundry is a public, production-oriented generator for new Phoenix
applications built around Ash, PostgreSQL, Inertia, and React.

The project is primarily maintained for its owner’s applications. It is public
so others may inspect and reuse it, but it is not being designed as a
community-governed project.

Confirmed project identity:

- Project name: **AshFoundry**
- Intended repository: `robertguss/ash-foundry`
- Core Hex package: `ash_foundry`
- Bootstrap archive: `ash_foundry_new`
- Primary command: `mix ash_foundry.new APP_NAME`
- License: **MIT**
- No contribution guide, issue templates, pull-request templates, code of
  conduct, or community-governance files

AshFoundry is intentionally Ash-first. It is not a general Phoenix starter with
Ash as an optional dependency.

## 2. Source applications inspected

AshFoundry is informed by three active applications and their associated Amp
threads:

1. `robertguss/wts-books-sours-app-elixir`
   - Thread: https://ampcode.com/threads/T-01a04f35-b872-76b9-a3ff-c330e1bcad1c
   - Inspected default-branch revision:
     `72a398b15480597ea3ed6657746676c4283c922c`
2. `robertguss/wts-internal-tools-elixir`
   - Thread: https://ampcode.com/threads/T-01a04e23-5573-76e7-9a0a-9784d0f25c9e
   - Inspected default-branch revision:
     `66cd86b1023b0a0bbaf3d90db828189965904b6c`
3. `robertguss/wts-library-scheduling-app-elixir`
   - Thread: https://ampcode.com/threads/T-01a04b5f-a491-7354-8686-812f811446c0
   - Inspected default-branch revision:
     `713ece7a1e95cba07715799a717927ae0ddd833a`

The repositories were inspected directly, not only through thread summaries or
planning documents. Uncommitted work described in a thread is not treated as
checked-in implementation.

### Patterns to retain and generalize

- Ash domains, resources, actions, policies, actor propagation, and committed
  resource snapshots
- Explicit server-side Inertia presenters rather than serializing Ash resources
- Encrypted Inertia history and CSRF-aware React integration
- Revocable, persisted authentication tokens and separate provider identities
- Default-deny policy tests and cross-tenant isolation tests
- PostgreSQL-enforced tenant relationships
- Oban supervision and deterministic test modes
- Transactional domain work and durable job insertion where required
- Separate liveness and database/migration-aware readiness endpoints
- Release migration helpers and non-root multi-stage Docker images
- Environment-specific, fail-closed production configuration
- Development-only personas
- Layered ExUnit, frontend unit, accessibility, and browser testing
- Clear separation between implementation evidence and plans
- Aggregate first-party analytics without employee leaderboards
- Append-oriented audit evidence

### Patterns not to copy

- WTS, bookstore, scheduling, department, Populi, Extensiv, Shopify, Slack,
  solver, or other product-specific domains
- Hard-coded hosted domains, sender identities, roles, queue names, service
  names, and provider flags
- Direct Ecto/SQL reads that bypass the intended Ash authorization boundary
  without a narrowly justified design
- Large controllers that own domain querying and serialization
- Unused dependencies such as packages added without an implemented extension or
  feature
- npm, package-lock files, Tailwind, or generated GitHub Actions
- App-specific setup scripts that mutate shell profiles, superuser passwords, or
  host services
- Product plans presented as implemented functionality
- A telemetry metric list without a production reporter presented as complete
  observability
- Unsafe bootstrap commands that print bearer invitation URLs into deployment
  logs
- Automatically exposing Ash resources through a public API

## 3. Generator architecture

AshFoundry uses a hybrid generator design:

1. Official `phx.new` creates the Phoenix foundation.
2. Igniter is the authoritative installation and transformation engine.
3. Official Ash installers are composed where applicable.
4. AshFoundry provides idempotent, capability-oriented Igniter tasks.
5. Static templates are used selectively for files that are not safely
   transformed through Elixir AST tooling, including React, CSS, JSON, Docker,
   deployment manifests, and documentation.
6. A thin Mix archive provides the friendly `mix ash_foundry.new` bootstrap
   command.

The generator will create **new applications only** in v1. It will not install
into arbitrary existing Phoenix projects.

Automated upgrades of generated applications are deferred beyond v1. Generated
source belongs to the application. AshFoundry records generation provenance and
choices in `.ash_foundry.exs`, while Renovate handles ordinary dependency
updates. Future releases may add narrowly scoped, explicitly safe migrations.

### Interactive and non-interactive operation

Running:

```bash
mix ash_foundry.new my_app
```

opens a concise interactive wizard. Every choice also has a command-line flag so
generation is deterministic and scriptable. The wizard prints the equivalent
complete command when it finishes.

Representative command:

```bash
mix ash_foundry.new my_app \
  --recipe internal \
  --auth google \
  --registration invite-only \
  --tenancy organizations \
  --deploy render
```

The normalized generation plan is written to `.ash_foundry.exs`.

### Intended distribution

- `ash_foundry_new` is distributed as a Hex archive.
- `ash_foundry` is distributed as a normal Hex package containing installers,
  recipes, templates, and metadata.
- Hex publishing is an intended outcome but remains a separate external action
  requiring explicit approval after local verification.

## 4. Recipes and capabilities

V1 contains four web-application recipes. Recipes are tested bundles of shared
capabilities, not forks or separate starter implementations.

| Recipe     | Default authentication | Registration       | Tenancy            |
| ---------- | ---------------------- | ------------------ | ------------------ |
| `internal` | Google                 | Invite-only        | None               |
| `saas`     | Google + password      | Open               | Organizations      |
| `personal` | Password + magic link  | Open               | None               |
| `custom`   | Explicit selection     | Explicit selection | Explicit selection |

All defaults are shown by the wizard and may be overridden.

Supported authentication selections:

- Google
- Password
- Magic link
- No authentication, through the custom recipe

Supported registration policies:

- Open
- Invite-only
- Closed

Supported tenancy architectures:

- None: genuinely non-multitenant, without dormant tenant columns or policies
- Organizations: organization membership, tenant switching, tenant-scoped
  policies, and database-enforced tenant relationships

Google hosted-domain restrictions are supported and default on for the internal
recipe, but the domain is application configuration rather than a hard-coded
value.

## 5. Runtime and package policy

AshFoundry uses only mutually compatible **stable** releases. Release
candidates, betas, alphas, and nightly packages are excluded unless a future
explicit experimental channel is designed.

“Latest” means:

- Latest patched stable Elixir release in the selected supported line
- Latest stable Erlang/OTP pairing supported by that Elixir release
- Active or Maintenance LTS Node.js, never the Current line in production output
- A complete dependency matrix verified together and committed through lockfiles
- Exact runtime/tool versions in mise, Docker build stages, and generated
  documentation

Current researched baseline at consolidation time:

- Elixir 1.20.4
- Erlang/OTP 29.0.5
- Phoenix 1.8.13
- Ash 3.32.1
- AshPostgres 2.12.0
- AshPhoenix 2.3.24
- AshAuthentication 4.14.2
- AshAuthenticationPhoenix 2.17.3
- Oban 2.24.0
- Inertia Phoenix 2.6.2 with a matching stable v2 React client
- React 19.2.8
- Mantine 9.5.2
- Vite 8.2.2
- Tidewave 0.9.0
- Swoosh 1.28.0
- Req 0.7.4
- Sentry 13.5.0
- Hammer 7.4.x
- PostgreSQL 18
- Node.js 24 LTS

The implementation pins this matrix rather than using floating generation
selectors. The verified frontend additions are pnpm 11.24.0, Inertia React
2.3.27, TypeScript 6.0.3, Biome 2.5.11, Vitest 4.1.11, and Playwright 1.62.1. A
newer stable release may replace a listed version only after the complete matrix
passes.

### Elixir typing policy

Elixir 1.20 has compiler-integrated, best-effort gradual set-theoretic
inference. It does not yet provide fully user-authored native type signatures or
a separate native `mix typecheck` command.

Generated applications therefore use all of:

- Full compilation with warnings treated as errors
- Compiler-native type diagnostics
- Erlang typespecs on public APIs, behaviours, process boundaries, and
  non-obvious contracts
- Dialyzer as a mandatory complementary project-wide analysis gate

The project must not describe Elixir 1.20 as fully statically typed.

## 6. Frontend architecture

Confirmed frontend stack:

- Phoenix controllers and Inertia as the browser application boundary
- React 19
- Strict TypeScript
- Vite through PhoenixVite
- Mantine 9 as the single v1 UI component system
- Mantine theme tokens and CSS Modules
- No Tailwind
- pnpm as the only supported frontend package manager in v1
- Client-rendered Inertia only
- No production Node SSR process

Node uses the latest verified LTS patch and is pinned exactly through mise. pnpm
is also pinned exactly. The same versions are used locally and in Docker asset
builds.

### Generated application shell

Every applicable recipe generates a small, polished, production-ready shell:

- Responsive authenticated layout and navigation
- Sign-in, registration, invitation, password-reset, and verification screens
  when enabled
- User profile and security settings
- Organization switcher when tenancy is enabled
- Organization membership and invitation administration
- System-administration surfaces appropriate to the recipe
- Loading, empty, validation, error, forbidden, and not-found states
- Light, dark, and system color modes
- A minimal dashboard demonstrating established patterns
- First-party feedback entry and administration for authenticated recipes
- Aggregate analytics views appropriate to the current actor

The shell does not include billing, subscriptions, a marketing site, or a fake
business domain.

### Presenter and TypeScript contract policy

- Ash resources are never serialized directly to Inertia.
- Every page uses an explicit Elixir presenter with an allowlisted JSON-safe
  map.
- Page props use colocated handwritten strict TypeScript types.
- ExUnit asserts presenter shape and redaction.
- Vitest tests pages with representative props.
- Playwright exercises real Phoenix/Inertia responses.
- AshTypescript is excluded in v1 because its resource/RPC-shaped output does
  not model deliberate Inertia presenter maps well.

## 7. Ash architecture

Ash is mandatory and used meaningfully in every recipe:

- Domains and resources
- Explicit actions and code interfaces
- AshPostgres data layer and migrations
- Default-deny Ash policies
- Actor propagation from authenticated Phoenix requests
- AshAuthentication for enabled authentication methods
- Tenant-aware resources and policy checks when organization tenancy is selected
- Policy and cross-tenant isolation tests

The generator does not add Ash extensions merely to list them as dependencies.
An extension is included only when generated code uses it.

Recommended data conventions to finalize during implementation include UUIDv7
primary keys, UTC microsecond timestamps, normalized/case-insensitive email
storage, and database constraints matching Ash identities and tenant boundaries.

## 8. Authentication and account security

Authentication providers and registration policy are separate generation
decisions. Public Google registration is supported; Google is not inherently
invite-only.

### Identity linking

- Provider identities are separate records keyed by trusted provider
  identifiers.
- Accounts are never automatically linked solely because email addresses match.
- If a provider claims an email already attached to an account, the user must
  authenticate through an existing method before linking.
- Linking and unlinking require recent authentication and create audit events.
- OAuth access and refresh tokens are not retained unless a future product
  explicitly needs them.

### Google

- Verified email is mandatory.
- OIDC state, nonce, signature, issuer, audience, expiry, and callback checks
  are mandatory.
- Invite-only registration requires a valid unconsumed invitation.
- Optional hosted-domain restrictions are validated from trusted claims.
- Google login alone is not represented as proof that the application’s MFA
  requirement was met.

### Password and magic link

- Argon2id is used instead of bcrypt for new password hashes.
- Reset, verification, invitation, and magic-link tokens are short-lived,
  purpose-bound, single-use, and hashed at rest.
- Authentication and recovery responses do not reveal whether an account exists.
- Authentication email disables provider click/open tracking by default.
- Email, token, password, session, and OAuth secrets are excluded from logs,
  audit metadata, Sentry, and analytics.

### Invitation links and system-admin bootstrap

- Invitations are app-generated, copyable bearer links.
- Every invitation is bound to a normalized intended email address.
- Acceptance requires the authenticated identity’s verified email to match the
  invitation email.
- Creating an invitation does not require Resend or any other email delivery.
- Initial system-admin bootstrap must also work through an app-generated invite
  link. The operator supplies the intended email for binding, and then delivers
  the generated link manually.
- Initial and emergency system-admin invitation links are generated only through
  explicit release commands.
- Normal organization invitation links are generated through authorized in-app
  administration.
- Existing system administrators may create another system-admin invitation
  through a separate, explicitly confirmed administrative action.
- Release commands display the link once and clearly warn that it is a 30-minute
  bearer credential.
- The database stores only a digest of the invitation token.
- Invitation tokens are cryptographically random, purpose/role-bound, expiring,
  revocable, and single-use.
- System-admin bootstrap and recovery invitations expire after 30 minutes.
- Normal membership invitations expire after seven days.
- Regenerating an invitation revokes every previous active link for that
  invitation.
- Generated links place the bearer token in the URL fragment, not the path or
  query string.
- The acceptance page removes the fragment from browser history immediately and
  exchanges the token through a CSRF-protected POST body.
- Invitation tokens therefore do not appear in HTTP access logs, request URLs,
  referrer headers, or normal server telemetry.
- Audit and analytics records store the invitation identifier, never its token
  or complete URL.
- Email delivery may be added by an application as a convenience, but it is not
  required by the invitation or bootstrap architecture.

### MFA and passkeys

MFA and passkeys are deferred from v1. Official AshAuthentication support is
currently in a release-candidate line, which conflicts with the stable-only
requirement and still has unresolved composition limitations.

The v1 account and session design must leave a clean extension seam for
passkey-first MFA, TOTP fallback, recovery codes, and recent-authentication
policy after the official packages become stable and have production soak time.

### Roles and authorization

Baseline role model:

- Global `system_admin` for platform administration and break-glass operations
- Organization membership roles: `owner`, `admin`, and `member`
- Non-tenant roles: `admin` and `member`
- Default-deny Ash policies
- Audited role changes
- No self-escalation
- The final organization owner cannot leave, be demoted, or be removed before
  transferring ownership

## 9. Organization tenancy

The organization-tenancy architecture supports users belonging to and owning
multiple organizations.

- Tenant context is explicit in organization-scoped URLs rather than existing
  only in mutable session state.
- The application reloads and authorizes membership for every tenant-scoped
  request.
- The organization switcher changes the URL, preserving safe deep links and
  multiple-tab behavior.
- Ash policies deny tenant data access without an authorized tenant.
- PostgreSQL constraints reinforce tenant ownership and relationships.
- Internal recipe: only system administrators create organizations.
- SaaS recipe: users may create organizations, subject to future product or
  billing policy.
- Invited SaaS users join the inviter’s organization without receiving an
  unwanted empty organization.
- Applications needing only one organization simply never expose additional
  organization creation.

## 10. Sessions and request security

Mandatory security baseline:

- Signed and encrypted cookies
- `__Host-` production cookie naming, `Secure`, `HttpOnly`, `SameSite=Lax`, no
  domain, and root path
- Session rotation after authentication
- Persisted token presence and revocation
- Session revocation after password changes, provider changes, account
  disablement, and logout-everywhere
- CSRF protection plus same-origin/fetch-metadata defense in depth
- Strict production Content Security Policy compatible with Vite and Mantine
- No production `unsafe-eval` or inline scripts
- Exact canonical-host validation
- Platform-specific trusted-proxy handling for Render and Fly
- HSTS without automatic subdomain/preload commitment
- Conservative request body, upload, query-string, header, and timeout limits
- No credentialed cross-origin CORS by default
- Security headers for framing, content-type sniffing, referrer behavior,
  permissions, and cross-origin isolation where safe
- Runtime secret validation that fails production startup for absent, blank,
  placeholder, or clearly weak secrets

### Rate limiting

- Hammer is the v1 rate-limiting implementation.
- Authentication, password reset, magic-link, invitation, Google OAuth, and
  email-send limits use both trusted client-IP and normalized identifier hashes.
- Sensitive routes fail closed if their limiter is unavailable.
- Generic responses and timing controls resist account enumeration.
- AshAuthentication’s durable brute-force audit controls complement in-memory
  limiting.
- The combined single-node deployment makes local ETS/atomic rate limiting
  acceptable for v1.
- Before horizontal web scaling, sensitive limits must move to a genuinely
  shared design, preferably PostgreSQL in this no-Redis architecture.

### Development ergonomics

Security must not make local development painful:

- Development mail uses Mailpit.
- Sentry and external webhooks are disabled.
- Development rate limits are generous and resettable.
- Argon2 uses cheaper development/test parameters while production keeps
  hardened values.
- Local HTTP uses a development cookie configuration; production enforces
  `Secure`/`__Host-` requirements.
- Development CSP allows only what Vite HMR and Tidewave require.
- Expensive security suites run through the comprehensive check command rather
  than every reload.
- Every generated app includes compile-time development-only persona sign-in
  with representative roles and organizations.
- Production release tests prove persona routes/modules are absent.

## 11. Tidewave

Tidewave is installed in every generated application as privileged development
tooling.

- Dependency scope is development only, not development-and-test.
- The endpoint plug is guarded by `Mix.env() == :dev` and installed in the
  required endpoint order.
- Remote access is false by default.
- No wildcard origins or permissive remote-container defaults are generated.
- Production releases and test builds must not include or mount Tidewave.
- Tests verify the production exclusion.

This boundary is mandatory because Tidewave can execute arbitrary Elixir and SQL
and relaxes some browser security policy while active.

## 12. Background work

Open-source Oban is standard infrastructure in every generated app.

- PostgreSQL remains the only required backing service; Redis is not introduced.
- V1 generates a single combined Phoenix + Oban release and deployment process.
- Split web/worker topology is intentionally deferred until an application needs
  independent scaling.
- Generated queue names remain generic; product-specific queues are not copied
  from source applications.
- Tests use Oban’s deterministic testing modes.
- Business records and jobs are inserted transactionally where the workflow
  requires atomicity.
- Final failures are normalized and reported without job arguments or sensitive
  metadata.
- Completed job history defaults to seven days.

AshOban is included only if generated code uses it meaningfully; it is not added
merely because Oban and Ash are both present.

## 13. Email

Confirmed email architecture:

- Swoosh as the provider-neutral mail boundary
- Req as the HTTP client
- Mailpit through Docker Compose in development
- Swoosh sandbox/test adapters in tests
- Resend as the only fully generated production provider in v1
- Application-owned HTML and text templates
- Durable delivery through Oban
- Provider message IDs and opaque application delivery IDs
- Signed, timestamp-checked, replay-deduplicated Resend webhooks
- Retry classification for timeouts, rate limits, and transient provider errors
- Delivery, bounce, complaint, and suppression handling
- No hosted provider templates by default
- No SMTP default

Auth routes commit account/token state before enqueueing mail. Provider
acceptance is not represented as inbox delivery.

Email delivery-event retention defaults to 90 days.

## 14. Audit

An append-oriented audit resource and appropriate audit UI are mandatory in v1.

Audit records contain only allowlisted fields such as:

- Event UUID and UTC timestamp
- Actor and target identifiers
- Organization identifier where applicable
- Action and bounded outcome/reason code
- Request ID
- Sanitized metadata

Audited behavior includes authentication, recovery, invitations, identity
linking, membership and role changes, privileged configuration, account
disablement, rate-limit denial/failure, and administrative actions.

Audit records expose no ordinary update/delete actions. Organization
administrators see only safe organization-scoped evidence. System administrators
receive an authorized global view. Personal users may review their own security
activity.

Audit is distinct from:

- Product analytics
- Application/domain record version history
- User-visible workflow milestones
- Operational telemetry
- Sentry errors

AshPaperTrail is not installed by default because generic record-version history
is not the same requirement and it was unused in one source application.

Default audit retention is **365 days**, enforced by an Oban maintenance task
with audit evidence. This is an operational default, not a compliance claim.

## 15. First-party analytics

Analytics are first-party, server-side, aggregate-only, and privacy-conscious.

Explicit exclusions:

- No external analytics vendor
- No browser tracker
- No page-view collection
- No click tracking
- No tracking cookie
- No browser fingerprinting
- No session replay
- No employee or user leaderboards
- No generic event warehouse
- No funnels, cohorts, or general time-series engine in v1

V1 provides authorized aggregate dashboard cards and projection conventions over
canonical Ash resources.

Baseline metrics include:

- Registered, verified, active, and disabled accounts
- Authentication-method adoption
- Organizations and memberships
- Invitation issuance and acceptance
- Meaningfully active users over 30/90 days
- Oban success, terminal failure, retry, queue, and execution summaries
  independent of short-lived Oban job history
- Email accepted, delivered, bounced, and complained counts
- Feedback volume, state, and resolution time

“Active” means a successful, meaningful authenticated server-side action. Page
navigation, frontend heartbeats, and passive page views do not count. Analytics
writes must never cause the underlying business action to fail.

Organization owners/admins see only their aggregate organization metrics. System
administrators may see authorized cross-organization aggregates and separately
protected security metrics.

The generator provides a documented projection interface for adding
domain-specific metrics from canonical domain facts. It does not invent a fake
business workflow.

## 16. Feedback

Every authenticated recipe includes first-party feedback:

- Authenticated submission
- Category, description, safe route context, organization, and reporter
- `new`, `acknowledged`, and `resolved` workflow
- Owner/admin feedback inbox
- Aggregate volume and resolution-time analytics
- Audit events for status changes
- No attachments in v1
- No automatic external delivery
- Clear instructions not to submit secrets or sensitive customer data

Feedback content is distinct from audit metadata and must never be sent
wholesale to logs, analytics, or Sentry.

Feedback retention follows explicit product handling rather than an automatic
generic purge.

## 17. Observability

Mandatory provider-neutral baseline:

- Human-readable development logs
- Structured JSON production logs to stdout
- Explicit metadata allowlist
- Request IDs and controlled job correlation
- Canonical Phoenix, Ecto, VM, and Oban telemetry metric definitions
- Private or authenticated Prometheus-compatible metrics
- Development-only LiveDashboard
- Separate `/healthz` liveness and `/readyz` readiness endpoints
- Database and packaged-migration readiness checks
- Sanitized terminal Oban failure reporting
- Shared PII/secret scrubbing with sentinel tests

Health probes do not create browser sessions and do not depend on third-party
provider availability. Queue health is monitored separately rather than ejecting
a healthy web process because a queue is delayed.

Sentry is the generated production error-reporting adapter. It remains inactive
until a DSN is configured.

Sentry defaults:

- No default PII
- Aggressive request, session, parameter, breadcrumb, Ash input, and
  job-argument scrubbing
- Terminal Oban failures rather than every transient retry
- No duplicate error reporting path

OpenTelemetry, AppSignal, Honeycomb, and other vendors are deferred as
additional adapters. The project must not represent the current BEAM
OpenTelemetry metrics/logs support as fully stable; stable tracing may be added
later.

## 18. Local development and mise

Mise is the primary local entry point.

- Exact Erlang, Elixir, Node LTS, and pnpm versions are pinned in `mise.toml`.
- Docker Compose runs PostgreSQL 18 and Mailpit.
- Developers do not need a host PostgreSQL installation.
- Primary commands include `mise run setup`, `mise run dev`, and
  `mise run check`.
- Setup is repeatable and must not modify shell profiles, reset host database
  superusers, or silently install global unpinned tools.
- Database creation, migrations, seed personas, frontend dependencies, and
  assets are handled through explicit tasks.

## 19. Deployment

V1 supports Render and Fly.io as first-class deployment targets.

The wizard requires one selection:

- `--deploy render`
- `--deploy fly`
- `--deploy none`

Only the selected provider’s files and runbook are generated. Both providers
share the same portable release/Docker foundation.

Deployment baseline:

- Multi-stage OCI image
- Exact toolchain versions
- pnpm asset build
- Phoenix release
- Unprivileged runtime user
- Minimal runtime packages
- Init/signal forwarding where required
- Explicit migration command; migrations do not run independently on every web
  boot
- Combined Phoenix + Oban process
- `/readyz` platform health check
- Graceful shutdown
- Runtime-only secrets
- No deployment automatically triggered by AshFoundry itself

The generated Fly configuration keeps its single combined Phoenix/Oban machine
running (`auto_stop_machines = "off"`) so scheduled and queued work is not
silently suspended. It uses a 120-second graceful `SIGTERM` window. Render and
Fly health checks target `/readyz`; production force-SSL handling excludes
`/healthz` and `/readyz` for direct platform probes on loopback hosts so those
checks return 2xx rather than a redirect.

## 20. Testing and local quality gates

Generated apps include local verification but no generated CI workflow.

Backend checks:

- Formatting
- Full warnings-as-errors compilation
- ExUnit and SQL Sandbox
- Ash policy and cross-tenant tests
- Ash code-generation/migration drift checks
- Credo strict
- Sobelow
- Hex retired-package audit
- Dependency advisory audit
- Dialyzer
- Production compile/release smoke path

Frontend checks:

- Strict TypeScript
- Biome formatting and linting
- Vitest
- Testing Library
- Automated accessibility assertions
- Production Vite build
- pnpm audit
- Playwright against Chrome/Chromium only

Playwright does not target Firefox or WebKit in v1.

No `.github/workflows` or equivalent CI files are generated. The owner
configures CI per application. The complete local gate remains available through
`mise run check` and `mix precommit`.

## 21. Dependency automation

Every generated project includes opt-in Renovate configuration but no Renovate
workflow.

- Supports Mix/Hex, mise, pnpm, Docker, and Docker Compose dependencies
- Weekly grouped update proposals
- Immediate known-security update proposals
- Stability delay for ordinary newly published packages
- Related Phoenix/Ash and React/Mantine updates grouped thoughtfully
- Major upgrades isolated
- Lockfile maintenance
- Docker digest pinning where support is reliable
- No automerge, especially because generated projects have no CI
- Nothing runs until the repository owner explicitly installs/enables Renovate

pnpm’s own supply-chain controls are also configured, including controlled
dependency build scripts and a minimum package-release age.

## 22. Public API and later versions

V1 web recipes are browser-first Inertia applications. They do not generate a
public JSON or GraphQL API.

An API-only recipe is planned as the first major v2 addition. It will be a
distinct architecture, not a switch that casually exposes web-application
resources. Its eventual scope includes AshJsonApi, OpenAPI, bearer/service
authentication, scopes, rate limiting, pagination, structured errors, audit, and
explicit CORS.

V1 does not add a generic API route or expose an Ash resource merely because it
exists.

## 23. Explicitly deferred or excluded from v1

- Installation into existing Phoenix projects
- Automated starter upgrades
- API-only recipe
- Mixed public API capability
- MFA, passkeys, TOTP, recovery codes, and trusted devices
- Inertia SSR and a production Node rendering process
- Billing and subscriptions
- Marketing site
- Generic analytics event warehouse, page analytics, funnels, and cohorts
- Split web/worker deployments
- Redis
- Kubernetes manifests
- Multiple UI libraries
- Tailwind
- AshTypescript
- AshPaperTrail by default
- Multiple production email providers
- External analytics vendors
- OpenTelemetry/AppSignal adapters
- CI workflows
- Firefox/WebKit browser support
- Automatic deployment, repository creation, Git push, Hex publication, or other
  external state changes without explicit approval

## 24. Superseded ideas

These were considered and explicitly replaced:

- shadcn/ui + Base UI → replaced by Mantine 9
- Tailwind → replaced by Mantine theme tokens and CSS Modules
- npm → replaced by pnpm
- Multiple separate internal/SaaS starter projects → replaced by one generator
  with recipes
- Universal organization model → replaced by distinct no-tenancy and
  organization-tenancy architectures
- Invite-only Google as the only Google mode → replaced by separate provider and
  registration-policy choices
- Combined and split worker topologies → v1 supports combined only
- Multiple deployment manifests in every output → generate only the selected
  provider
- Full automatic starter upgrades → deferred
- Public API in v1 → API-only recipe deferred to v2
- Three-browser Playwright matrix → Chrome/Chromium only
- Generated CI → omitted

## 25. External actions and implementation decisions

The only remaining open items are external mutations. They must not be performed
without explicit approval:

1. **Repository creation:** creating `robertguss/ash-foundry` on GitHub is an
   external action and requires explicit approval.
2. **Hex publication:** intended, but actual package/archive publication
   requires explicit approval after verification.

### Decisions settled during implementation

The following implementation decisions were settled on 2026-08-30:

- The initial repository and both package versions are `0.1.0`.
- Generation does not initialize Git or create an initial commit. This avoids
  changing user repository state and keeps deterministic acceptance fixtures.
- Organization records use UUIDv7 primary keys and an immutable, unique slug in
  URLs. Display names may be renamed without breaking links; changing a slug is
  an explicit application migration rather than normal UI behavior.
- Internal applications default to a 12-hour absolute session and 30-minute idle
  timeout. SaaS and personal applications default to a 30-day absolute session
  and 12-hour idle timeout. Every authenticated request reloads the persisted
  token, and security-sensitive account changes revoke sessions.
- `AshFoundry.Analytics.Projection` is the generated extension behaviour.
  Implementations return aggregate, authorization-scoped cards from canonical
  facts. `AshFoundry.Analytics.mark_meaningful_action/3` records only successful
  authenticated server-side actions, after the business result, and analytics
  failure never changes that result. Feedback submission is the generated
  concrete meaningful action. Its marker is tenant-scoped when organizations are
  enabled, and tenant policy tests prove owners can see only their
  organization's marker.
- Audit resources expose no public update or destroy action. The 365-day purge
  is isolated in a maintenance worker that performs a narrowly scoped repository
  delete and appends one aggregate retention event in the same transaction. The
  documentation describes this as application-level append orientation, not
  database immutability.
- Prometheus metrics are exposed only on a separate endpoint guarded by a
  constant-time bearer-token check. Render and Fly runbooks require a private
  network or provider access control in addition to the token; no public
  unauthenticated scrape endpoint is generated.
- Render and Fly both use the same release image and explicit `eval` migration
  command. Fly uses a `release_command`; Render uses `preDeployCommand`.
- Fly's combined web/worker machine remains always on and uses a 120-second
  `SIGTERM` grace period. Direct loopback health paths are excluded from
  production SSL redirects because Fly HTTP health checks require a 2xx and do
  not follow redirects.
- Provider manifests were checked against current official Render and Fly
  documentation. Credential-free local verification cannot prove live OAuth,
  Resend delivery/webhooks, Sentry ingestion, private provider networking,
  DNS/TLS, or an actual provider deployment; generated integrations remain
  disabled until their runtime credentials are configured.
- When `--module` differs from the OTP application name, AshFoundry-owned module
  paths use the underscored requested module. Module-independent paths stay at
  their documented names. Files retained from the official Phoenix installer may
  keep OTP-application filenames while declaring the requested module; the
  generator removes only stale installer targets whose app and module paths
  genuinely differ.
- Closed registration with magic-link authentication uses a read action for
  `sign_in_with_magic_link`; recipes that permit registration use a create
  action. This preserves sign-in without allowing the strategy to create an
  account in a closed application.
- Organization creation tests and fixtures are recipe-aware. SaaS users may
  create their own organization. Non-SaaS recipes exercise the stricter system
  administrator creation path, then assign the tested owner, and include a
  direct policy assertion that an ordinary user cannot create an organization.
- A conditionally rendered template whose result is blank is removed instead of
  leaving an empty capability file. This is particularly important for the
  Google-only user-identity resource and custom no-auth outputs.
- The last-owner invariant uses a typed Ecto query against the generated
  membership schema rather than interpolated or raw SQL. The generated security
  gate therefore passes strict Sobelow without suppressing a query finding.
- No-auth routers fetch LiveView flash data before Inertia, matching Inertia's
  controller contract. Authenticated and unauthenticated Playwright smoke tests
  assert the actual rendered shell, not only the health endpoint.
- AshAuthenticationPhoenix 2.17.3 refers to the removed upstream type
  `Ash.Resource.record/0` in one callback declaration. Auth outputs contain a
  single exact Dialyzer ignore for that upstream warning. Generated callback
  code itself is Dialyzer-clean; the inactive-user path preserves the real
  authentication activity rather than calling `failure/3` with an invalid nil
  activity.

### Credential-free acceptance evidence

The v1 acceptance matrix was executed in a fresh Linux orb with Erlang/OTP
29.0.5, Elixir 1.20.4, PostgreSQL 18.6, Node.js 24.20.0, and pnpm 11.24.0:

- Fresh internal, SaaS, personal, and custom applications were generated through
  `ash_foundry_new` after the official `phx.new`, Ash, AshPostgres, and
  AshPhoenix installers. Each recipe compiled and its backend/frontend tests
  ran. The no-auth custom fixture also proved the absence of authentication,
  organization resources/routes, and provider deployment files.
- A critical override combined the internal recipe with password plus magic
  link, closed registration, organization tenancy, Render deployment, and
  `--module OpsPortal`. It passed formatting, warnings-as-errors compilation,
  Ash migration drift, 18 ExUnit tests, strict Credo, strict Sobelow, retired
  and dependency audits, Dialyzer, TypeScript/Biome, four Vitest component and
  accessibility tests, production Vite build, pnpm audit, and two Chromium
  Playwright smoke tests.
- The final no-auth custom fixture passed formatting, warnings-as-errors
  compilation, migrations, Ash migration drift, eight ExUnit tests, strict
  Credo, strict Sobelow, retired and dependency audits, TypeScript/Biome,
  Vitest, production Vite build, pnpm audit, and Chromium Playwright smoke
  tests.
- The generator package passed formatting, warnings-as-errors compilation,
  strict Credo, 11 ExUnit tests, retired/dependency audits, Dialyzer, and a
  local Hex package build with the expected MIT metadata and template contents.
  The thin archive passed four ExUnit tests, built and installed locally, and
  exposed the documented `mix ash_foundry.new` help and options.
- A SaaS production release built successfully, rejected a weak
  `SECRET_KEY_BASE`, migrated a fresh production database through its release
  command, started with valid runtime configuration, and returned 200 responses
  from `/healthz` and `/readyz`. Its release applications and BEAM/router
  content excluded Tidewave, personas, the mailbox, and development routes.
- Render and Compose YAML parsed successfully. Render targets `/readyz` and uses
  `/app/bin/migrate`; Fly TOML parsed successfully, targets `/readyz`, uses an
  explicit release command, remains always on, sends `SIGTERM`, and allows 120
  seconds for shutdown. The three exact Docker base tags resolve in the
  registry, and static Dockerfile checks prove a non-root release with the
  production asset build and health check. This orb has neither a Docker daemon
  nor the Compose plugin, so an actual image/Compose build could not be executed
  locally.
- Google OAuth redirects, Resend delivery and webhook callbacks, Sentry
  ingestion, provider-private networking, DNS/TLS, and live Render/Fly
  deployments require credentials or provider accounts and were not exercised.
  No GitHub repository, push, deployment, Hex publication, Renovate enablement,
  or other external mutation was performed.

## 26. Required implementation discipline

- Generate the smallest architecture that fulfills these decisions.
- Prefer official Phoenix, Ash, Igniter, and provider installers over copied or
  forked generators.
- Use stable packages only and pin a tested matrix.
- Keep generated code understandable and application-owned.
- Do not claim deployment, provider delivery, security compliance, accessibility
  conformance, or upgrade safety without executed evidence.
- Exercise every generated recipe and supported override in a bounded acceptance
  matrix.
- Verify that production releases exclude Tidewave, development personas, local
  mail tooling, and development-only routes.
- Verify that generated applications start from a clean checkout using only
  documented prerequisites.
- Keep external mutations fail-closed until credentials and explicit
  configuration are present.
- Never create a repository, push code, deploy, publish packages, or enable
  external automation without explicit approval.
