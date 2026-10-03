# Friends Included Finance

Day 4 homework application for Emīls Štībelis. Vercel hosts the website and API; Supabase stores the authoritative records; Telegram accepts submissions and delivers decisions; Google Sheets receives a readable copy. No AI service is used at runtime.

## Setup

1. Create a Supabase project. Run `supabase/schema.sql` once in its SQL Editor. Save the project URL and server-side service role key in Vercel environment variables. Never expose the service role key to the browser.
2. Ask Telegram **@BotFather** to create a bot with `/newbot`. Store its token as `TELEGRAM_BOT_TOKEN`. Generate a random `TELEGRAM_WEBHOOK_SECRET` using letters, numbers, underscores and hyphens. Set `PUBLIC_BOT_USERNAME` without `@`.
3. Create a Google Cloud project, enable the Google Sheets API, create a service account and download its JSON key. Set `GOOGLE_SERVICE_ACCOUNT_EMAIL` and `GOOGLE_PRIVATE_KEY` from that file. The private key can contain real newlines or escaped `\n`.
4. Create a Google spreadsheet with exactly two tabs named **Sales** and **Expenses**. Share it with the service account email as Editor. Set `GOOGLE_SHEET_ID`. Give the instructor Viewer access. The application manages row positions: do not insert, delete or sort rows directly; use filter views for checking.
5. Create a GitHub repository containing this directory and import it into Vercel. Choose framework **Other**, no install or build command, and output directory **public**. The `api/` directory contains Vercel Node functions. Set every variable in `.env.example`, including the repository and deployed app URLs. Redeploy after changing environment variables.
6. Connect Telegram with `npm run webhook` using the same environment variables. This sends `setWebhook` to Telegram with the public HTTPS URL and the webhook secret. No token is printed by the script.
7. Open your bot privately and send `/start`. Select Svetlana on the website. Link the ID shown by `/whoami` to a fictional employee. Unlinked users cannot submit; the bot never accepts role assignment commands.

## Local use

Node 22 or newer is required. No package installation is needed.

```
node --env-file=.env scripts/dev.mjs
node --test tests/*.test.mjs
node --env-file=.env scripts/webhook.mjs
```

Copy `.env.example` to `.env` privately. Never commit `.env`, the service account JSON, or bot credentials. The local app is at http://127.0.0.1:3000. With no Supabase configuration it clearly reports that the database is not connected; it does not substitute simulated records.

## Enter and approve

Sales roles enter sales and the proposed split. Kevin enters expenses. Svetlana sees the dashboard, all original proposals, approval controls, and Telegram links. Changing the final commission split or allocation at approval preserves the original proposal. Transactions are immutable after approval. Pending transactions can be left pending indefinitely.

Telegram formats:

```
/sale S01 | Olivia Rose | A | One proud uncle and an emotional grandmother | 1000 | 50,30,20
/expense E01 | Rented suit and fake pearl necklace for the relatives | 120 | Materials | A
```

Website and bot both use `submission()` and the same atomic database functions. Role checks run in both the HTTP handler and SQL procedures. The demonstration selector intentionally allows choosing any fictional role, as required by the exercise. It is not an authentication system for real business data.

## Live acceptance tests

Follow `TESTING.md` in order. Begin with an empty database. Do not load mock records for S01 and E01: both must be submitted through the actual Telegram bot. The tests supplied in the repository validate calculations and input rules; they do not prove live integration behavior. The live SQL regression checks use a rollback transaction and do not populate the homework records.

## Delivery recovery

Submission and approval atomically queue delivery jobs in Supabase. A failed external call does not roll back financial records. Each record shows Sheets and Telegram states separately and provides Retry delivery. Retry processes the same reference, using its assigned sheet row, and never appends a duplicate row. Approval locks the database row and returns the existing decision on repeated approval. Telegram update IDs protect submissions against webhook retries.

Website entries capture an available employee chat at submission. If no chat was linked, approval may resolve a newly linked chat; this supports the S03 and E04/E05 notification tests. Bot entries always retain their original chat and employee even after relinking.

Google Sheets calls use RAW input to prevent descriptions being interpreted as spreadsheet formulas. Rows use numeric amounts and separate proposed/final percentage columns. Pending sales have blank approved percentages and zero earned commission. Delivery jobs use leases to avoid concurrent retries for the same reference. Telegram does not support sendMessage idempotency keys: a rare process crash after sending but before marking delivery may produce a repeated message on retry.

Official implementation references: [Vercel Node functions](https://vercel.com/docs/functions/runtimes/node-js), [Supabase database functions](https://supabase.com/docs/guides/database/functions), [Telegram webhooks](https://core.telegram.org/bots/api#setwebhook), [Google Sheets writes](https://developers.google.com/workspace/sheets/api/samples/writing).
