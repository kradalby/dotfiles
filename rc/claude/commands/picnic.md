---
description: Picnic grocery shopping — restock from history, clean-ingredient picks
---

Manage the Picnic cart via the `mcp__picnic__*` tools. Never check out or pick a delivery slot unless asked.

## Workflow

1. **Cart**: `picnic_get_cart`. Flag sold-out lines (unit price `99999`, line price `0`) and duplicate lines of the same product.
2. **History**: `picnic_get_deliveries` (limit 50), then `picnic_get_delivery` for every COMPLETED one. Count per product: how many orders it appears in, usual quantity, date last bought.
3. **Propose**: recurring items missing from the cart, grouped by frequency (almost always / often / sometimes). Note items overdue relative to their usual interval.
4. **Ask with a checklist**: `AskUserQuestion` with `multiSelect: true`, default quantity = usual quantity. Batch into several questions if needed; no prose asking.
5. **Add**, then **verify**: after every add, re-read the returned cart. If price is `99999`, the item is sold out: remove it and go to substitution.
6. **Summary**: what was added, what was skipped or sold out, new total.

## Choosing products (search, substitutions, new items)

Always read ingredients: `picnic_get_product_details` with `full: true`.

Priority, in order:
1. **Clean**: short ingredient list, whole foods. Avoid ultra-processed (preservatives, emulsifiers, thickeners, flavourings, sweeteners, modified starch). Clean beats cheap.
2. **Quality**: better quality beats cheaper.
3. **Price**: when ingredients and quality are the same, the cheapest per kg wins. The brand does not matter (house brand or named brand).

If only ultra-processed options exist, do not pick silently — ask, showing the ingredient difference. Stay pragmatic: a single benign additive (e.g. lactic acid in cheese) is fine.

## Gotchas

- Add/remove are not idempotent. On an error, re-read the cart before you retry.
- Search does not show stock. Sold-out shows only after adding.
- Promo labels in product details are not always applied in the cart. Report a mismatch; do not assume a discount.
- Prices are in cents.
