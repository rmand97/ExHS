# Task 15 — Public forening pages

## Goal
Each forening has a public-facing site at `forening.exhs.dk` with branding, info, upcoming events, and (view-only) merchandise.

## Prerequisites
- Task 4 (subdomain routing), Task 9 (Events), Task 10 (Shop scaffold), Task 14 (design system)

## Plan

### Routing
- [ ] Public scope mounted under forening subdomain
- [ ] No auth required for public pages (auth required for actions)

### Public LiveViews
- [ ] `PublicLive.Home` — forening info, hero with branding, mission/about text
- [ ] `PublicLive.Events.Index` — upcoming events listing
- [ ] `PublicLive.Events.Show` — single event detail, ticket types, "register" CTA (redirects to sign-in / membership upsell if not eligible)
- [ ] `PublicLive.Shop.Index` — products grid (view-only)
- [ ] `PublicLive.Shop.Show` — single product page
- [ ] `PublicLive.NotFound` — branded 404

### Branding
- [ ] Layout reads forening branding from assigns
- [ ] CSS custom properties drive theme
- [ ] Forening logo in header, footer

### Join CTA
- [ ] Public "Become a member" page — explains kontingent, links to sign-up flow
- [ ] Sign-up flow: register user → join forening → checkout kontingent (handoff to Task 8 flow)

### SEO / metadata
- [ ] Per-page OG tags
- [ ] Sitemap.xml endpoint
- [ ] Robots.txt aware of forening structure

### Cookie consent
- [ ] Banner (only for analytics/tracking cookies; functional cookies don't need consent under GDPR)
- [ ] Preferences stored in cookie + respected by analytics scripts

### Tests
- [ ] Public pages render without authentication
- [ ] Branding loads correctly
- [ ] Visiting wrong subdomain shows branded 404

## Open decisions
- [ ] **Static content management** — admin-editable "about" page (rich text editor) vs developer-managed?
- [ ] **Custom pages per forening** — should foreninger be able to add arbitrary pages?
- [ ] **Analytics** — Plausible, Umami, Fathom, none?

## Done when
- Two foreninger have distinct public pages with their branding
- Visitor can browse events and merch without logging in
- "Join" flow takes anonymous visitor → registered → active member end-to-end
