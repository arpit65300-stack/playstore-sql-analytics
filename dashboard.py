import streamlit as st
import pandas as pd
import psycopg2
import os
import plotly.express as px
from scipy.stats import chi2_contingency

# ---------- Page setup ----------
st.set_page_config(page_title="Google Play Store Analytics", layout="wide")
st.title("📊 Google Play Store — Product Analytics Dashboard")

# ---------- DB connection ----------
@st.cache_data
def load_data():
    conn = psycopg2.connect(
        host="localhost",
        database="playstore_analysis",
        user="postgres",
        password=os.environ.get("DB_PASSWORD", ""),  # set DB_PASSWORD env var before running
        port=5432
    )
    df = pd.read_sql("SELECT * FROM apps_clean;", conn)
    conn.close()
    return df

df = load_data()

# ---------- Sidebar filter ----------
categories = sorted(df["category"].dropna().unique())
selected_cats = st.sidebar.multiselect("Filter by category", categories, default=categories)
filtered_df = df[df["category"].isin(selected_cats)]

# ---------- Section 1: Category installs vs rating ----------
st.header("1. Installs vs. Rating by Category")

cat_summary = (
    filtered_df.dropna(subset=["rating"])
    .groupby("category")
    .agg(num_apps=("app_name", "count"), avg_rating=("rating", "mean"), total_installs=("installs", "sum"))
    .reset_index()
    .sort_values("total_installs", ascending=False)
)
cat_summary["install_rank"] = cat_summary["total_installs"].rank(ascending=False)
cat_summary["rating_rank"] = cat_summary["avg_rating"].rank(ascending=False)
cat_summary["rank_gap"] = cat_summary["rating_rank"] - cat_summary["install_rank"]

fig1 = px.bar(cat_summary.head(15), x="category", y="total_installs",
              hover_data=["avg_rating", "install_rank", "rating_rank"],
              title="Top 15 Categories by Total Installs")
st.plotly_chart(fig1, use_container_width=True)

st.subheader("Biggest opportunity gaps (high installs, low rating rank)")
st.dataframe(cat_summary.sort_values("rank_gap", ascending=False).head(5)[
    ["category", "num_apps", "avg_rating", "total_installs", "install_rank", "rating_rank"]
])

# ---------- Section 2: Update-recency cohort trend ----------
st.header("2. Rating Trend by Update-Recency Cohort")

cohort_df = filtered_df.dropna(subset=["rating", "last_updated"]).copy()
cohort_df["update_month"] = pd.to_datetime(cohort_df["last_updated"]).dt.to_period("M").dt.to_timestamp()
cohort_summary = (
    cohort_df.groupby("update_month")
    .agg(num_apps=("app_name", "count"), avg_rating=("rating", "mean"))
    .reset_index()
)
cohort_summary = cohort_summary[cohort_summary["num_apps"] >= 10]  # filter noisy early months

fig2 = px.line(cohort_summary, x="update_month", y="avg_rating",
               title="Average Rating by App Update Month (Maintenance-Recency Proxy)",
               markers=True)
st.plotly_chart(fig2, use_container_width=True)

# ---------- Section 3: A/B test — Free vs Paid ----------
st.header("3. A/B Test — Free vs. Paid Pricing on Rating")

ab_df = df.dropna(subset=["rating"])
ab_df = ab_df[ab_df["type"].isin(["Free", "Paid"])].copy()
ab_df["rating_bucket"] = ab_df["rating"].apply(lambda r: "High" if r >= 4.0 else "Low")

contingency = pd.crosstab(ab_df["type"], ab_df["rating_bucket"])
chi2, p, dof, expected = chi2_contingency(contingency)

col1, col2 = st.columns(2)
with col1:
    st.write("Contingency Table")
    st.dataframe(contingency)
with col2:
    st.metric("Chi-square statistic", f"{chi2:.2f}")
    st.metric("p-value", f"{p:.3f}")
    if p < 0.05:
        st.success("Statistically significant at 95% confidence")
    else:
        st.info("Not statistically significant at 95% confidence")

st.caption("Built by Arpit Kumar — PostgreSQL, Python, Streamlit")
