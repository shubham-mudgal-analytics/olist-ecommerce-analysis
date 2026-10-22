# Findings Summary — Olist E-Commerce Analysis

> All numbers come from the SQL queries (SSMS, DB: `ecommerce`) and were re-checked in Excel.
> This file is the source for the README.

---

## Excel validation (status: complete)

| # | Check | Expected | Result |
|---|---|---|---|
| 1 | Q2 revenue column sum = last running total | 13,179,777.95 | ✅ match |
| 2 | Q3 top 8 revenue % sum | 54.5 | ✅ match |
| 3 | Q4 reviews total / % total | 99,224 / 100 | ✅ match |
| 4 | Q5 late % recalculated | 8.11% | ✅ match |
| 5a | Q6 one-star share of late orders | 37.8% (3,554 / 9,405) | ✅ match |
| 5b | Q7 customers total | 93,350 | ✅ match |
| R | Jan 2017 revenue from raw CSV (filters + lookup) | 111,798.36 | ✅ match |

---

## FINDING 1 — Late delivery vs review score (MAIN FINDING)

**Query:** orders JOIN order_reviews, delivered orders with a delivery date, grouped by delivery status.

| Delivery Status | Orders | % of Orders | Avg Review Score | 5-Star | 1-Star | Low Review % (≤2) |
|---|---|---|---|---|---|---|
| **Late** | 7,700 | **7.99%** | **2.57** | 1,711 | 3,554 | **54.03%** |
| **On Time** | 88,653 | 92.01% | **4.29** | 55,348 | 5,851 | 9.23% |
| **Total** | 96,353 | 100% | — | 57,059 | 9,405 | — |

### Derived numbers
- **Score drop:** (4.29 − 2.57) / 4.29 × 100 = **40.1%**
- **Share of 1-star reviews:** late orders are 7.99% of reviewed delivered orders, but **37.8%** of all 1-star reviews (3,554 / 9,405).
- **1-star rate:** late **46.2%** (3,554 / 7,700) vs on-time **6.6%** (5,851 / 88,653). That is about **7×**.
- **Low review (≤2):** late 54.03% vs on-time 9.23%. That is about **5.9×**.

### Headline
> Late deliveries are about **8% of reviewed delivered orders**, but their average rating is **40% lower** (4.29 → 2.57), and they account for **38% of all 1-star reviews**.

**Limit:** this is an association in observational data, not proof that lateness causes low ratings.

---

## FINDING 2 — Promise padding (delivery time)

- Average promised time: **24.00 days** (Q5).
- Average actual time: **12.00 days per order** (Q5). Q1 shows **12.41 days per item**, because it counts item rows.
- On-time rate is high because promised dates are generous, not only because logistics are fast.

---

## FINDING 3 — Retention is very low

- Customers counted by `customer_unique_id` (the real customer; `customer_id` changes per order).
- Customer base: **93,350**.
- One-time: **90,549 (97.00%)**. Repeat (2+ orders): **2,801 (3.00%)**.

---

## FINDING 4 — Revenue is concentrated

- Total product revenue: **13,220,248.93 BRL** (delivered orders with a delivery date).
- Top category: **health_beauty**, 1,233,131.72 BRL, **9.33%**.
- Top 8 categories: **54.5%** of revenue.

---

## FINDING 5 — Trend window

- Monthly trend covers **Jan 2017 to Aug 2018**. 2016 is excluded (very few orders).
- Last month with delivered orders that have a delivery date: **Aug 2018** (838,576.64 BRL).
- Monthly revenue for 2017–2018 totals **13,179,777.95 BRL**.

---

## DATA QUALITY (7 checks, all run)

| # | Check | Result | Impact |
|---|---|---|---|
| 1 | NULL values | Only delivered date = **2,965** (never-delivered orders, by design) | none |
| 2 | Duplicate order_id | **0** | none |
| 3 | Duplicate review_id | **789** (known Olist source issue) | handled at order level |
| 4 | Date logic | Delivered before purchase = 0; approved before purchase = 0; **carrier date before purchase = 166** | flagged, not deleted |
| 5 | Orphan records | **0 / 0 / 0** | none |
| 6 | Numeric ranges | Price 0.85 to 6,735; freight 0 to 409.68; zero or negative = 0 | none |
| 7 | Category mapping | **610** products with no category, **13** with no English translation (3 pc_gamer + 10 portateis), total **623** (1.9%) | kept with LEFT JOIN, shows NULL |

### Extra data finding (found while reconciling)
- **8 delivered orders have no delivery date.** They were included in one query and not another.
- Effect: **1,249.18 BRL** and **8 customers**.
- After the delivery-date filter was added everywhere, Q2, Q7 and the Excel checks all match.

### Reconciling row totals (expected, not errors)
- 96,470 delivered orders (Q5) − 646 with no review = 95,824
- 95,824 + 529 duplicate review rows = **96,353** review rows (Q6)

---
