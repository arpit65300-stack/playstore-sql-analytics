# Google Play Store — SQL Analytics & A/B Testing

An end-to-end product analytics project on the Google Play Store apps dataset (~10,800 apps), built with PostgreSQL, Python, and Streamlit. Simulates the kind of ad-hoc analysis and experimentation a product data analyst would run on app-store data.

## Tech Stack
- **PostgreSQL** — data storage, cleaning, and analysis (window functions, CTEs, aggregations)
- **Python** — `pandas`, `scipy` for statistical testing
- **Streamlit + Plotly** — interactive dashboard

## What This Project Does
1. **Data cleaning** — Raw Kaggle data ships with inconsistent formats (`"10,000+"` install counts, `"$4.99"` prices, `"19M"` sizes, non-UTF8 characters, a malformed row). Cleaned and cast every column to proper types in SQL.
2. **Category-level analysis** — Used `RANK()` window functions to compare install volume vs. average rating across categories.
3. **Cohort-style trend analysis** — Grouped apps by last-updated month as a maintenance-recency proxy, tracking rating trends over time.
4. **A/B test simulation** — Chi-square test of independence to check whether pricing model (free vs. paid) is associated with rating outcomes.
5. **Interactive dashboard** — Streamlit app surfacing all three analyses with filters.

## Key Findings
- **Category opportunity gap**: The **Tools** category drives **6.83%** of total installs — the 5th highest of any category — but ranks **32nd of 33** categories on average rating, the widest install-vs-rating gap in the dataset.
- **Maintenance-recency trend**: Apps updated more recently trend toward higher ratings — average rating climbed from ~4.05 (early 2017 cohort) to **4.33** (August 2018 cohort), suggesting active maintenance correlates with user satisfaction.
- **Pricing A/B test**: A chi-square test comparing free vs. paid apps on rating outcome (High ≥4.0 vs. Low <4.0) returned **χ² = 2.72, p = 0.099** — not statistically significant at 95% confidence. Pricing model alone does not appear to drive rating outcomes.

## Running It Locally
1. Load the [Google Play Store dataset](https://www.kaggle.com/datasets/lava18/google-play-store-apps) into PostgreSQL (schema + cleaning steps in `dashboard.py` assume a table `apps_clean`).
2. Install dependencies:
   ```
   pip install streamlit psycopg2-binary pandas plotly scipy
   ```
3. Set your database password as an environment variable:
   ```
   set DB_PASSWORD=your_postgres_password
   ```
4. Run the dashboard:
   ```
   streamlit run dashboard.py
   ```

## Author
Arpit Kumar — IIT Delhi
