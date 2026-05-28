# Task 15 — Public forening pages

## Goal
Each forening has a public-facing site at `forening.exhs.dk` with branding, info, upcoming events, and (view-only) merchandise.

## Prerequisites
- Task 4 (subdomain routing), Task 9 (Events), Task 10 (Shop scaffold), Task 14 (design system)

## Plan

### Routing
- [x] Public scope mounted under forening subdomain
- [x] No auth required for public pages (bypass policies for public read actions)

### Public LiveViews
- [x] `PublicLive.Home` — forening hero with branding, about section, upcoming events, join CTA. Also serves as marketing landing page when no subdomain.
- [x] `PublicLive.Events.Index` — upcoming events listing
- [x] `PublicLive.Events.Show` — single event detail, ticket types, "tilmeld" CTA (redirects to sign-in if not logged in)
- [ ] `PublicLive.Shop.Index` — products grid (view-only) — deferred, depends on Task 10
- [ ] `PublicLive.Shop.Show` — single product page — deferred, depends on Task 10
- [x] Branded 404 + 500 error pages (Danish text, ErrorHTML templates)

### Branding
- [x] Layout reads forening branding from assigns (`Layouts.public/1`)
- [x] CSS custom properties drive theme (`forening_css_vars/1`)
- [x] Forening logo in header, footer (logo_url or initial fallback)

### Join CTA
- [x] Public "Bliv medlem" page — explains kontingent, lists benefits, links to sign-up
- [ ] Sign-up flow: register user → join forening → checkout kontingent (handoff to Task 8 flow)

### SEO / metadata
- [x] Per-page OG tags (title, description, image via assigns in root layout)
- [x] Sitemap.xml endpoint (dynamic, includes events for forening subdomains)
- [x] Robots.txt (dynamic, disallows /auth/ and /admin/)

### Cookie consent
- [x] Banner (analytics vs essential, shown if no consent cookie)
- [x] Preferences stored in `exhs_consent` cookie, `hasAnalyticsConsent()` exported for analytics scripts

### Tests
LiveView tests via `Phoenix.LiveViewTest` — focus on mount + primary interactions, not markup details.

- [x] Public pages mount and render without authentication (13 tests)
- [x] Tenant isolation: cross-tenant event visibility, cross-tenant event access, bidirectional isolation (4 tests)
- [x] Redirects without subdomain
- [ ] Branding loads correctly (forening colour/logo show up on the right subdomain)
- [x] Visiting wrong subdomain shows branded 404
- [ ] Sign-up / contact form (if any) submits and produces the expected effect

### Decided
- Routes in English (`/events`, `/join`), UI text in Danish
- Public read actions use `bypass` policies (not `policy`) so unauthenticated access works without actor
- Forening loaded via session in LiveView (conn → session → `LiveForeningAuth` hook) since LiveView connects via websocket, not HTTP
- Marketing landing page and forening home share the same `/` route, differentiated by presence of `current_forening`

## Open decisions
- [ ] **Static content management** — admin-editable "about" page (rich text editor) vs developer-managed?
- [ ] **Custom pages per forening** — should foreninger be able to add arbitrary pages?
- [ ] **Analytics** — Plausible, Umami, Fathom, none?

## Done when
- Two foreninger have distinct public pages with their branding
- Visitor can browse events and merch without logging in
- "Join" flow takes anonymous visitor → registered → active member end-to-end
