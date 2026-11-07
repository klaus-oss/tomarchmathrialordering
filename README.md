# ARCH-MAT: Material Ordering Platform

A single-page web app where approved members order architecture materials and an admin verifies and tracks the orders.

- **Frontend:** one static file, `index.html` (Tailwind CSS pre-built and inlined, no build step)
- **Backend:** [Supabase](https://supabase.com) (Postgres, Auth, Row Level Security, Realtime)
- **Hosting:** any static host (Netlify, Cloudflare Pages, GitHub Pages)

## Features
- Member login with Member ID + PIN, first-time activation with the registered phone
- Catalog with category filters, search, cart, notes per item, order history, cancel pending orders
- Admin: authorize/remove members, reset a member PIN, manage materials, search/filter orders, change status, print slip, CSV import/export
- Live order status updates

## Setup
1. Create a Supabase project.
2. In the SQL Editor run, in this order: `schema.sql`, `pin_reset.sql`, then `first_admin.sql` (with your own details). Optionally `sample_materials.sql`.
3. In Supabase go to Authentication, Providers, Email and turn **off** "Confirm email".
4. In `index.html` set `SUPABASE_URL` and `SUPABASE_ANON_KEY` (Project Settings, API). Only use the anon/publishable key, never the service_role key.
5. Deploy `index.html` to any static host.
6. Open the site, tick "First time? Activate", enter the admin Member ID, phone and a PIN.

## Security notes
- Access rules are enforced by Row Level Security in `schema.sql`, not by the page.
- Anyone who knows a member's ID and phone can activate an unactivated account, so keep those private.
