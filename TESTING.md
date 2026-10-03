# Live homework acceptance checklist

Use an empty Supabase project for the course tests. Do not clear test 1 records before test 2. The instructor can enter new transactions after these tests; totals must change normally.

## First connection milestone

Start the real Telegram bot. Link your ID to Richard using Svetlana's manager setup. Submit S01 using the command below. Confirm the success message arrives only after saving; the pending record appears in Supabase, on the website, and in the Sales sheet. Leave it pending until all test 1 entries are recorded. S01 is your first real transaction, so no practice records need clearing.

```
/sale S01 | Olivia Rose | A | One proud uncle and an emotional grandmother | 1000 | 50,30,20
```

Relink the same ID to Kevin and submit E01:

```
/expense E01 | Rented suit and fake pearl necklace for the relatives | 120 | Materials | A
```

## Test 1 website entries

As Anastasia, enter S02: Daniel King; project B; University friends, dancing, and the stripping performance; €2,000; proposed split 0 / 50 / 50.

As Kevin, enter E02: Taxi for the grandmother; Kevin selected the wrong project; Travel; €80; proposed B. Enter E03: Monthly company website subscription; Other; €100; Company overhead.

Before decisions: project results €0 / €0, company result −€300, income and commissions €0. S01 and S02 pending; E01/E02 awaiting allocation; E03 allocated overhead.

As Svetlana: approve S01 unchanged; approve S02 with 20 / 40 / 40; allocate E01 to A; change E02 to A. Receive S01 and E01 notifications in the original bot chat despite relinking. For S02 and E02, check the linked destination or the explicit No Telegram recipient linked status.

Verify A result €700; B result €1,800; company €2,400; Richard €90; Anastasia €110; Jean-Claude €100. Inspect the actual Sheets rows and refresh the website.

## Test 2 website entries

Jean-Claude: S03; Emma Stonebridge; A; Premium relatives, including an uncle presented as a surgeon; €1,500; 40 / 40 / 20.

Richard: S04; Lucas Green; B; Small group of loud university friends; €800; 25 / 25 / 50. S05; Mia Brooks; B; Extra guests and an embarrassing speech; €600; 100 / 0 / 0.

Kevin:

| Reference | Description | Category | EUR | Proposed |
| --- | --- | --- | ---: | --- |
| E04 | Replacement costumes after an enthusiastic dance performance | Materials | 250 | B |
| E05 | Minibus for university friends; Kevin selected the wrong project again | Travel | 90 | A |
| E06 | Company telephone subscription | Other | 60 | Overhead |
| E07 | Emergency replacement clothing; project allocation still needs checking | Materials | 140 | A |

Link your Telegram ID to Jean-Claude before approving S03 at 20 / 30 / 50. Verify the changed-split message gives a €150 pool and commissions €30 / €45 / €75. Approve S04 unchanged. Leave S05 pending.

Relink to Kevin before allocating E04 to B and changing E05 from A to B. Verify E05 reports €90 moved from A to B. Leave E07 awaiting allocation. E06 is automatically overhead and needs no decision message.

| Measure | A | B | Company |
| --- | ---: | ---: | ---: |
| Approved income | 2500 | 2800 | 5300 |
| Commissions | 250 | 280 | 530 |
| Allocated project expenses | 200 | 340 | 540 |
| Overhead | — | — | 160 |
| Awaiting allocation | — | — | 140 |
| Result | 2050 | 2180 | 3930 |

Commission earned: Richard €140, Anastasia €175, Jean-Claude €215. S05 is €600 pending and excluded; E07 is €140 awaiting allocation and already deducted from company result. Reconcile €2,050 + €2,180 − €160 − €140 = €3,930.

## Denied actions and recovery

Attempt 60 / 30 / 20 split; approval as Richard; sale submission as Kevin; missing/zero expense amount; repeat approval; duplicate reference. All must leave totals unchanged. Run `supabase/regression.sql` to additionally exercise the database processing layer. Its rollback removes its own temporary records.

After completing the twelve records, retry an existing reference while the service account's Editor sharing is temporarily removed. A failed synchronization must appear; restore sharing and retry. Verify the same assigned sheet row updates and financial totals remain unchanged. Never delete the row or alter the transaction to recover delivery.

To test a failed notification, use a fresh fictional transaction while the bot is blocked by its recipient; approve it. Verify the decision remains saved and Notification failed appears. Unblock and start the bot, then Retry delivery. Restore any temporary practice data by using a separate test Supabase project for this optional destructive setup; do not delete the completed homework records.

## Submit

The app footer must link to the real bot, instructor-viewable spreadsheet, and accessible GitHub repository. Give the instructor access where needed. Verify the Vercel page shows Emīls Štībelis and the completed results. Put its one working URL in your own Day 4 row in the course spreadsheet. Do not submit an unconnected app.
