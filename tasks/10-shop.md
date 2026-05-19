# Task 10 — Shop (mostly TBD)

## Goal
Foreninger can sell merchandise (physical + digital). The shape of this task is intentionally underspecified — most of the detail is deferred until we have real foreninger feedback.

> **Heavy TBD warning.** Do not start this task without an explicit product-scoping conversation. The plan below is a placeholder skeleton.

## Prerequisites
- Task 8 (Payments)

## Plan (placeholder)

### Shop domain
- [ ] `Exhs.Shop` domain module
- [ ] Register in `ash_domains`

### Product resource (skeleton)
- [ ] `Exhs.Shop.Product` at `lib/exhs/shop/product.ex`
- [ ] Multitenancy: `:attribute` on `forening_id`
- [ ] Attributes: `id`, `name`, `description`, `price_cents`, `currency`, `type` (atom: `:physical | :digital`), `stock_quantity` (nullable for digital), `image_url`, `published` (bool), timestamps

### Order resource (skeleton)
- [ ] `Exhs.Shop.Order` at `lib/exhs/shop/order.ex`
- [ ] Multitenancy: `:attribute` on `forening_id`
- [ ] `belongs_to :membership`, `belongs_to :product`, `belongs_to :payment`
- [ ] Attributes: `quantity`, `total_cents`, `status` (atom: `:paid | :fulfilled | :cancelled`), `shipping_name`, `shipping_address`, `shipping_postal_code`, `shipping_city`, timestamps
- [ ] Change module `DecrementStock` (atomic) for physical products

### Code interface
- [ ] `Exhs.Shop.list_products/1`
- [ ] `Exhs.Shop.purchase/3` (creates pending order + Stripe checkout)

## Open decisions (all TBD)
- [ ] **Digital products** — what counts as "digital"? PDF downloads? Software licenses? Access codes? Streaming?
- [ ] **Digital delivery mechanism** — signed S3 URLs, in-app download page, emailed link?
- [ ] **Stock semantics** — single SKU per product, or variants (size, color)?
- [ ] **Cart** — single-item buy-now, or full cart with multiple line items?
- [ ] **Shipping cost / tax** — flat rate? Based on weight? Tax-inclusive pricing?
- [ ] **Returns / refunds** — flow, who triggers, how stock is restored
- [ ] **Fulfillment tracking** — track shipping numbers? Notify member?
- [ ] **External marketplace integration** — Shopify hand-off vs build in-house?
- [ ] **Inventory adjustments** — admin UI to bump stock without orders?
- [ ] **Sold-out behavior** — backorder, waitlist, or hard-block?

## Done when
- (Cannot define — needs scoping conversation first)
- Minimum acceptable: admin can list a physical product with stock; member with active membership can buy one; Stripe payment creates Order; stock decrements atomically
