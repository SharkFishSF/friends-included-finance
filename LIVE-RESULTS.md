# Live verification — 3 October 2026

Application: https://friends-included-finance-peach.vercel.app/

Completed both homework scenarios using the real Supabase database, Telegram bot and Google Sheets service account. S01 and E01 were submitted by the student through Telegram; the other ten records were entered through the deployed website.

All twelve records show Synced. Telegram-connected submissions and decisions show Sent. Website sales without a linked recipient explicitly show No Telegram recipient linked. S03 received a linked recipient before its corrected-split approval. S01's original bot destination was preserved after the account was reassigned to Kevin.

Final results, verified after reloading the deployed app:

| Measure | EUR |
| --- | ---: |
| Project A result | 2050 |
| Project B result | 2180 |
| Company result | 3930 |
| Richard commissions | 140 |
| Anastasia commissions | 175 |
| Jean-Claude commissions | 215 |
| Pending sale S05 | 600 |
| Expense E07 awaiting allocation | 140 |

Test one: before approvals, project results were zero and company result was -300. Final test-one results were A 700, B 1800 and company 2400; commissions 90 / 110 / 100. The second test retained the first test's records.

The live invalid S05 approval attempt with a 60 / 30 / 20 split was rejected. S05 remains pending and financial totals were unchanged.

An empty successful Supabase RPC response initially caused delivery errors. The database response parser was corrected and deployed. S01 delivery was recovered by Retry delivery on the existing record; Sheets and Telegram then succeeded without creating another transaction. The automated recovery test now uses real Response objects, including HTTP 204 responses. All six automated tests pass. Database rollback regression assertions also passed.

The spreadsheet was verified visually with real Sales records and shared as Viewer for anyone with its link. The app URL was saved to the student's own Day 4 link cell Q57 in the course submission sheet; Saved to Drive and the exact URL were verified.

Limits: selectable website roles are intentional for this fictional course demonstration, not production authentication. Blocking Telegram recipients and revoking Google sharing were simulated in automated tests, not additionally induced against the completed live homework. Telegram delivery cannot guarantee exactly once after a crash between sending and recording success; retries keep financial decisions and assigned spreadsheet rows unchanged.
