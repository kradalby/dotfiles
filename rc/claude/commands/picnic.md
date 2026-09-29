---
description: Picnic grocery shopping — restock from history, clean-ingredient picks
---

Manage the Picnic cart via the `mcp__picnic__*` tools. Never check out or pick a delivery slot unless asked.

## Household

Two people. Mostly vegetarian. Quick (≤30 min), simple, clean; mix rich and fresh.

- Base: beans (favourite), potato, pasta.
- Protein: prefer high-protein recipes; suggest boosts (extra beans/lentils, eggs, cottage cheese, Greek yoghurt).
- Avoid: goat cheese, walnuts, beets. Skip recipes that need them; never suggest them in restock, even if they appear in order history.

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

**Non-food** (cleaning, household): the clean rule does not apply; effective chemicals are wanted. Pick what does the job, then cheapest per litre/unit. Prefer spray bottles over refill bottles for cleaners.

## Recipes

Order history does not record recipes; use the cookbook (`picnic_get_saved_recipes`) and browse.

1. **Find**: `picnic_browse_recipes` with categories `recipe_cattree_vega` and `recipe_cattree_20minuten`; prefer recipes in both. Always give the link `https://picnic.app/nl/recepten/<id>`.
2. **Check**: `picnic_get_recipe` for time and ingredients. Apply the product rules above to each ingredient. Propose a clean swap (e.g. liquid stock for a stock cube, own spices for a spice mix); drop recipes that need too many swaps.
3. **Group** proposals as fresh / rich. Prefer recipes that use staples from order history.
4. **Save**: ask with a checklist, then `picnic_save_recipe` / `picnic_unsave_recipe`.
5. **Shop**: do not use `picnic_add_recipe_to_cart` blindly. Get ingredients (`picnic_get_multiple_recipe_ingredients`), scale to 2 portions, merge across recipes and the current cart, and buy the largest sensible pack (one 1 L milk, not two 500 ml). Skip items already in the cart or pantry. Ask with a checklist before adding.

## Gotchas

- Add/remove are not idempotent. On an error, re-read the cart before you retry.
- Search does not show stock. Sold-out shows only after adding.
- Promo labels in product details are not always applied in the cart. Report a mismatch; do not assume a discount.
- Prices are in cents.
