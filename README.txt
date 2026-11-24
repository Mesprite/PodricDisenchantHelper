Podric DE Check v0.1.1 - WoW Forever
==================================
What it does
------------
On eligible green/blue/purple gear tooltips, adds:
  Vendor value
  Expected value of materials from disenchanting
  DISENCHANT or VENDOR recommendation and the difference
  Age of Crafter's Journal's last AH scan

No Auctionator or Auctioneer required. The addon ONLY READS
CraftersJournalDB; it does not replace or change Crafter's Journal.
It can be run next to an existing disenchant tooltip addon.

Install
-------
1. Quit World of Warcraft completely.
2. Put the PodricDECheck folder into:
   World of Warcraft/_forever_/Interface/AddOns/
3. Check that Crafter's Journal is enabled.
4. Start WoW and inspect a green gear item's tooltip.
5. For prices, use Crafter's Journal to complete a full AH scan.

How it compares
---------------
The value of keeping materials is evaluated at the AH's LOWEST
unit buyout observed during Crafter's Journal's most recent scan.
Expected DE value = sum(chance x average quantity x material AH price).
This is BUY-REPLACEMENT value, not how much you'd take home after
auction fees. That matches the intended question: "Should I vendor
this and buy mats, or disenchant it for mats myself?"

If any material lacks a scanned AH price, the addon shows the known
value as a LOWER BOUND. It only recommends disenchanting if even this
lower bound beats vendoring. Otherwise it makes no recommendation.
A 12+ hour old scan is flagged stale. Repeat a scan for better data.

Known limitations
-----------------
* Uses Classic disenchant brackets; unusual Forever items can differ.
* Uses base/full-condition vendor value from item data; damaged
  equipment may vendor for less than the tooltip shows.
* Lowest buyouts can be one-off undercuts; this is an estimate.
* Displays its OWN extra tooltip section. It does not replace the
  original addon price fields, so other addons may still say "no price".
* Supports CJ 0.67+ ruleset/faction keys and older realm/faction keys.
* v0.1.1 compatibility fix tested in simulated Lua; not yet tested in WoW.

Source is provided in PodricDECheck.lua for straightforward editing.

Changes in v0.1.1 (2026-11-21)
--------------------------------
Read the new gm<mode>-<faction> scan keys and CJ last-known market
when the game mode is not available, retaining legacy realm lookup.
No changes to disenchant tables, material price fields or calculations.
Requires CJ v0.67.0 or later for the new Forever client.


Version 0.1.2: Auctionator completed full-scan material snapshots take priority; Crafter's Journal supplies missing prices. Run a full scan after installing to populate the new snapshot. Quick scans and shopping searches do not replace it. Prices are marked stale after six hours; failed scans retain the last successful snapshot. Both price addons are optional. Classic-derived disenchant estimates are unchanged.
