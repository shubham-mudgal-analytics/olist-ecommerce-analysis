# Olist E-Commerce Sales Analysis

## Business problem

An online marketplace wants answers to three questions:

1. **Why are customer ratings low?**
2. **Where does the revenue come from?**
3. **Do customers come back to buy again?**

**Stakeholder:** marketplace operations and customer experience team. This is a portfolio project built on public data. It is not work for a real company.

## Direct answers

1. **Ratings:** Late deliveries are linked to much lower ratings. **54.03%** of late orders get a 1–2 star review, compared with **9.23%** of on-time orders. This is an association, not proof that lateness causes low ratings.
2. **Revenue:** Revenue is concentrated. The **top 8 categories** make up **54.49%** of product revenue.
3. **Repeat purchase:** Very few customers return. **97.00%** of customers placed only one order.

## Recommendations

1. **Track late deliveries every week.** Late orders are 7.99% of reviewed delivered orders, but they are 37.8% of all 1-star reviews. Track the late rate and the share of 1-star reviews each week. Next step: find out which carriers, sellers, or regions cause the late orders. This was not analysed in this project.
2. **Test tighter delivery promises.** Customers are promised about 24 days, but orders arrive in about 12 days. A shorter promise might keep most orders on time, but this is untested. Run a small test and compare the on-time rate and the late rate.
3. **Test a second-purchase offer.** 97% of customers never come back. Send an offer to a sample of first-time buyers and compare their repeat rate with a group that gets no offer. The data cannot show whether an offer would work.
4. **Watch category dependence.** The top 8 categories make up 54.49% of revenue. Keep stock and service levels strong in these categories, and watch the risk of depending on a few categories.

## Dataset

- Olist Brazilian marketplace data: **99,441 orders** across **9 tables**.
- Provider: Olist. Kaggle lists André Sionek as co-author.
- Kaggle describes the data as real commercial data that has been anonymised.
- Source: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
- Licence: CC BY-NC-SA 4.0 (see Licence below).
- Dates in the data: first delivered order **11 October 2016**, last delivered order **17 October 2018** (SQL `00`, Q8).
- Currency: BRL (Brazilian real).
- The raw CSV files are not included in this repository.

## Privacy

- The dataset has no customer names. Customers are identified by anonymised IDs. This analysis uses only `customer_unique_id`.
- The Kaggle page says company and partner names in the review text were replaced with Game of Thrones house names. Review comment text is not used or published in this project.
- The raw CSV files are not in this repository.

## Tools

- **SQL Server (SSMS):** data quality checks and business analysis
- **Excel:** validation of query results (22 checks)
- **Power BI:** dashboard (1 page)

## Approach

1. **Data quality checks:** row counts first, then 7 checks on nulls, duplicates, impossible dates, orphan keys, value ranges, and category mapping (SQL `00`).
2. **Analysis:** 7 business queries covering revenue, categories, ratings, delivery performance, and customer retention (SQL `02`).
3. **Excel validation:** 22 checks in `outputs/p1_excel_validation.xlsx`. 21 checks compare SQL results with Excel calculations (totals, percentages, shares, and cross-checks between queries). 1 check recalculates January 2017 revenue from the raw CSV files with Power Query. Both methods give **111,798.36 BRL**. All 22 checks pass.
4. **Dashboard:** Power BI page with KPI cards, a monthly revenue trend, a rating comparison, and top categories.

## Data quality

| Check | Result | How it is handled |
|---|---|---|
| Duplicate `order_id` | 0 | None needed |
| Orphan records across tables | 0 | None needed |
| Delivered before purchase | 0 | None needed |
| Missing delivery date | 2,965 orders have no delivery date. 8 of them have status `delivered` (see below). | Only delivered orders with a date are used in revenue and delivery analysis |
| Duplicate `review_id` | 789 | Reviews are handled at order level |
| Carrier date before purchase date | 166 orders (0.17% of 99,441) | Flagged, not deleted |
| Numeric ranges | Price 0.85 to 6,735. Freight 0 to 409.68. No zero or negative prices. | None needed |
| Missing category | 623 products (1.9%): 610 with no category, 13 with no English translation | Kept with a LEFT JOIN. Category name shows as NULL. |
| Delivered orders with no delivery date | 8 orders, revenue 1,249.18 BRL (SQL `00`, Q11) | Excluded from revenue and customer counts |
| Delivered orders with no review | 646 | Excluded from the rating analysis (INNER JOIN) |

## Key findings

### 1. Late delivery is linked to lower ratings (SQL `02`, Q5 and Q6)

- Late orders: **7,700** of 96,353 reviewed delivered orders (**7.99%**). On-time orders: 88,653.
- Average review score: late orders **2.57 stars**, on-time orders **4.29 stars**. That is a **40.1% drop**.
- 1-star rate: **46.2%** for late orders (3,554 of 7,700), compared with **6.6%** for on-time orders (5,851 of 88,653).
- Low reviews (1–2 stars): **54.03%** for late orders, compared with **9.23%** for on-time orders.
- Late orders are 7.99% of reviewed delivered orders, but **37.8%** of all 1-star reviews (3,554 of 9,405).
- This is an association in observational data. It is not proof that lateness causes low ratings.

### 2. Promised delivery time is much longer than actual time (SQL `02`, Q5 and Q1)

- Customers are promised about **24 days** on average (**24.00 days**, Q5).
- Orders arrive in about **12 days** on average (**12.00 days per order**, Q5).
- Q1 shows **12.41 days per item**. Q1 counts each item row, so orders with more items weigh more.
- The high on-time rate reflects generous promised dates, not only fast logistics.

### 3. Very few customers come back (SQL `02`, Q7)

- Customer base: **93,350** customers, counted by `customer_unique_id`. `customer_id` changes with every order, so it is not used to count customers.
- **90,549** customers (**97.00%**) placed only one order.
- **2,801** customers (**3.00%**) came back for another order.

### 4. Revenue is concentrated in a few categories (SQL `02`, Q3 and Q3b)

- Total product revenue: **13,220,248.93 BRL** (delivered orders with a delivery date).
- The top category, **health_beauty**, makes **1,233,131.72 BRL** (**9.33%**).
- The top 8 categories make **7,203,513.11 BRL** (**54.49%**).

| Rank | Category | Share of product revenue |
|---|---|---|
| 1 | health_beauty | 9.33% |
| 2 | watches_gifts | 8.82% |
| 3 | bed_bath_table | 7.74% |
| 4 | sports_leisure | 7.22% |
| 5 | computers_accessories | 6.72% |
| 6 | furniture_decor | 5.39% |
| 7 | housewares | 4.66% |
| 8 | cool_stuff | 4.62% |

### 5. Monthly revenue trend (SQL `02`, Q2)

- The trend uses the **purchase month**.
- January 2017: **111,798.36 BRL** from 750 orders.
- August 2018: **838,576.64 BRL** from 6,351 orders.
- Total for January 2017 to August 2018: **13,179,777.95 BRL**.
- 2016 is left out of the trend because it has very few orders. By delivery month (SQL `00`, Q9 and Q13), 2016 has 267 delivered orders (40,470.98 BRL): October 205, November 58, and December 4.
- September and October 2018 have 59 delivered orders (11,744.44 BRL) (SQL `00`, Q12).

## Metric definitions

- **Revenue:** sum of `order_items.price` for **delivered** orders with a delivery date. Freight is excluded from revenue. Freight is 2,198,145.90 BRL and is shown separately in Q1.
- **Late order:** the order status is delivered, and `order_delivered_customer_date` is later than `order_estimated_delivery_date`.
- **Late delivery %:** late orders ÷ delivered orders. On the dashboard: 7,826 ÷ 96,470 = **8.11%**.
- **Customer:** `customer_unique_id`.
- **Average order value (AOV):** product revenue ÷ distinct delivered orders = **137.04 BRL** (Q1).
- **Monthly trend:** revenue by purchase month (`order_purchase_timestamp`). KPI cards and the delivery-month check (SQL `00`, Q13) use the delivery date.

## Reconciling the numbers

Different queries show different counts. Each difference is explained:

- **Delivered orders:** 96,470 (Q5). Minus 646 with no review = 95,824 reviewed orders. Plus 529 duplicate review rows = **96,353** review rows (Q6).
- **Late share has two bases:**
  - **7.99%** = 7,700 late of 96,353 review rows. Used in the rating finding.
  - **8.11%** = 7,826 late of 96,470 delivered orders. Used on the dashboard.
  - The difference does not change the 40.1% rating finding.
- **Revenue by month has two bases:**
  - SQL `02` Q2 counts by purchase month: 13,179,777.95 BRL for January 2017 to August 2018.
  - SQL `00` Q13 counts by delivery month: 13,168,033.51 BRL for the same period.
  - The gap is **11,744.44 BRL**. That is exactly the September–October 2018 delivered revenue (SQL `00`, Q12 and Q13), so the two views reconcile.
- **Total product revenue:** 2016 delivered (40,470.98) + January 2017 to August 2018 by delivery month (13,168,033.51) + September–October 2018 (11,744.44) = **13,220,248.93 BRL** (Q1).

## Dashboard

Power BI dashboard, **1 page built**:

- **KPI cards:** Total Revenue (13,220,248.93 BRL), Delivered Orders (96,470), Late Orders (7,826), Late Delivery % (8.11%)
- **Monthly revenue trend:** January 2017 to August 2018, by purchase month
- **Average review score:** on-time vs late
- **Top 8 categories** by revenue

Which question each part answers:

| Question | Where it is answered |
|---|---|
| 1. Why are ratings low? | Average review score: on-time vs late. SQL `02` Q5 and Q6. |
| 2. Where does the revenue come from? | Total revenue KPI, monthly trend, top 8 categories. SQL `02` Q1 to Q3. |
| 3. Do customers come back? | Not on the dashboard. Answered in SQL `02` Q7 only. |

![Olist Sales Performance dashboard](images/dashboard.png)

## Repository structure

```
olist-ecommerce-analysis/
├── sql/
│   ├── 00_verify_import_and_quality.sql   -- row counts, 7 data quality checks, reconciliation checks
│   └── 02_analysis_queries.sql            -- 7 business queries
├── outputs/
│   └── p1_excel_validation.xlsx           -- SQL outputs and Excel validation checks
├── powerbi/
│   ├── olist_dashboard.pbix               -- Power BI file
│   └── olist_theme.json                   -- dashboard theme
├── images/
│   └── dashboard.png                      -- dashboard screenshot
└── README.md
```

## How to run

1. Import the Olist CSV files into a SQL Server database named `ecommerce`.
2. Run the SQL files in SSMS in this order:
   - `00_verify_import_and_quality.sql`
   - `02_analysis_queries.sql`
3. Each file is split into batches with `GO`. Run each file as a whole.
4. `outputs/p1_excel_validation.xlsx` contains the SQL outputs and the validation checks.

## Notes from the build

These are mistakes I made and fixed. They are listed here so the process is clear.

- **`RowCount` is a reserved keyword** in SQL Server and caused a syntax error. Renamed to `TotalRows`.
- **Power BI cut the time part of the delivery date.** `order_delivered_customer_date` was loaded as Date, so same-day late deliveries were counted as on time. The late count was lower than the SQL count (7,826). Changing the column to Date/Time fixed it.
- **Totals did not match at first** (96,470 delivered vs 96,353 review rows). Reconciled using the 646 orders with no review and the 529 duplicate review rows.
- **Revenue did not match between Power BI and SQL.** Power BI showed 13,181,027.13 BRL and SQL showed 13,179,777.95 BRL. The difference is 1,249.18 BRL, the revenue of the 8 delivered orders with no delivery date (SQL `00`, Q11). Adding the delivery-date filter to the monthly query fixed the match.

## Limitations

- The data covers marketplace orders only. Seller costs and margins are not included, so profit is not analysed.
- Ratings are a proxy for satisfaction. Not every customer leaves a review (646 delivered orders have no review).
- The rating finding is an association, not causation.
- The causes of late delivery (carrier, seller, region) are not analysed.
- Freight is not included in revenue.
- The monthly trend covers January 2017 to August 2018 only. 2016 has too few orders.
- The data is a fixed snapshot. A customer who buys after the data period is not counted, so the repeat rate may be understated.
- The dashboard answers questions 1 and 2. Question 3 is answered in SQL only.
- SQL and Power BI use different dates for different views: purchase month for the trend, delivery date for the KPI cards. Each chart label shows which one it uses.
- The dataset is a public release. It may not reflect how the marketplace works today.

## Licence

- **Dataset:** CC BY-NC-SA 4.0, as listed on the Kaggle dataset page (checked 31 October 2026). Use requires attribution to Olist, non-commercial use only, and derivative work shared under the same licence.
- The dataset is not included in this repository. Only the analysis (SQL, Excel, Power BI, and write-up) is shared.
