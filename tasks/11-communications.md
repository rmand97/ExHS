# Task 11 — Communications & newsletters

## Goal
Admins compose and send segmented newsletters; we track delivery and opens. Reusable segments for repeated targeting.

## Prerequisites
- Task 4 (Membership), Task 6 (Groups, for segmentation), Task 9 (Events, for attendance-based segmentation)

## Plan

### Communications domain
- [ ] `Exhs.Communications` domain module
- [ ] Register in `ash_domains`

### Segment resource
- [ ] `Exhs.Communications.Segment` at `lib/exhs/communications/segment.ex`
- [ ] Multitenancy: `:attribute` on `forening_id`
- [ ] Attributes: `id`, `name`, `description`, `filter_definition` (map/JSONB), timestamps
- [ ] Filter definition schema covers:
  - [ ] Membership status (active/inactive)
  - [ ] Group membership (any of / all of)
  - [ ] Attended event (specific event IDs)
  - [ ] Purchased product (specific product IDs)
  - [ ] Boolean combinations (AND/OR/NOT)

### Newsletter resource
- [ ] `Exhs.Communications.Newsletter` at `lib/exhs/communications/newsletter.ex`
- [ ] Multitenancy: `:attribute` on `forening_id`
- [ ] Attributes: `id`, `subject`, `body_html`, `body_text`, `status` (atom: `:draft | :scheduled | :sending | :sent | :failed`), `scheduled_for`, `sent_at`, timestamps
- [ ] `has_many :recipients` (NewsletterRecipient)
- [ ] Optional `belongs_to :segment` (for "send to this segment"; can also use ad-hoc filter)
- [ ] Code interface: `schedule_send`, `send_test`, `cancel`

### NewsletterRecipient resource
- [ ] `Exhs.Communications.NewsletterRecipient` at `lib/exhs/communications/newsletter_recipient.ex`
- [ ] Multitenancy: `:attribute` on `forening_id`
- [ ] `belongs_to :newsletter`, `belongs_to :membership`
- [ ] Attributes: `delivery_status` (atom: `:queued | :delivered | :bounced | :failed`), `delivered_at`, `opened_at`, `open_count` (int), timestamps
- [ ] Identity: unique `(newsletter_id, membership_id)`

### Segment resolution
- [ ] Function: `Exhs.Communications.resolve_segment/2` → list of Memberships
- [ ] Reusable from newsletters and ad-hoc admin views
- [ ] Must be tenant-scoped and policy-aware

### Sender plumbing
- [ ] Swoosh mailer with chosen provider (TBD — see open decisions)
- [ ] Email template rendering (HEEx → HTML + plain text)
- [ ] Unsubscribe link per recipient (signed token)
- [ ] Open tracking pixel endpoint (1x1 GIF, records `opened_at`)
- [ ] Bounce/complaint webhook (provider-specific)

### Sending pipeline
- [ ] Oban worker `NewsletterSender` (Task 13) iterates recipients in batches, marks status as it goes
- [ ] Rate-limited per provider constraints

### Compliance
- [ ] Every email includes physical address (Danish legal requirement check)
- [ ] Easy unsubscribe (one-click), respected on next send
- [ ] Suppression list per forening (do-not-email)

### Tests
- [ ] Segment resolution returns expected memberships
- [ ] Sending creates NewsletterRecipient rows
- [ ] Worker handles partial-batch failures (retries individuals)
- [ ] Open tracking endpoint records hits

## Open decisions
- [ ] **Email provider** — Postmark (great deliverability, transactional+broadcast), Resend (modern), SES (cheap, more setup), Mailgun, Brevo?
- [ ] **Per-forening sending domain** — verified custom domain per forening, or shared `mail.exhs.dk` with friendly-from?
- [ ] **Newsletter editor UX** — plain HTML / markdown / WYSIWYG / block editor?
- [ ] **Test-send flow** — to admin only, or to any email?

## Done when
- Admin builds segment, drafts newsletter, sends to segment
- Delivery + open tracking works
- Unsubscribe works and is respected
- Recipient list is correctly tenant-scoped
