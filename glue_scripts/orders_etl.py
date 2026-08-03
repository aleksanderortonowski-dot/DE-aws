
import sys
import logging
from datetime import datetime

from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F
from pyspark.sql.types import DecimalType, TimestampType, LongType

# -- Setup --
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

args = getResolvedOptions(sys.argv, [
    "JOB_NAME",
    "SOURCE_BUCKET",
    "TARGET_BUCKET",
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

SOURCE_BUCKET = args["SOURCE_BUCKET"]
TARGET_BUCKET = args["TARGET_BUCKET"]
RUN_DATE = datetime.utcnow().strftime("%Y-%m-%d")

logger.info(f"START | job={args['JOB_NAME']} | source={SOURCE_BUCKET} | target={TARGET_BUCKET} | date={RUN_DATE}")


# -- Extract --
def read_parquet(bucket: str, prefix: str):
    path = f"s3://{bucket}/{prefix}/"
    logger.info(f"Reading: {path}")
    df = spark.read.parquet(path)
    logger.info(f"Rows read: {df.count():,}")
    return df


orders_raw = read_parquet(SOURCE_BUCKET, "raw/orders")

customers_raw = read_parquet(SOURCE_BUCKET, "raw/customers")

customers = (customers_raw
    .select("customer_id", "country", "segment")
    .dropDuplicates(["customer_id"])
)


# -- Transform --
def transform_orders(df):
    logger.info("Transform: casting types")

    df = (df
        .withColumn("order_id",     F.col("order_id").cast(LongType()))
        .withColumn("customer_id",  F.col("customer_id").cast(LongType()))
        .withColumn("total_amount", F.col("total_amount").cast(DecimalType(12, 2)))
        .withColumn("ordered_at",   F.col("ordered_at").cast(TimestampType()))
    )

    # Data quality: filtruj nieprawidlowe rekordy
    invalid = df.filter(
        F.col("order_id").isNull() |
        F.col("customer_id").isNull() |
        (F.col("total_amount") < 0)
    ).count()
    logger.warning(f"DQ: dropping {invalid} invalid rows")

    df = df.filter(
        F.col("order_id").isNotNull() &
        F.col("customer_id").isNotNull() &
        (F.col("total_amount") >= 0)
    )

    # Deduplikacja po order_id
    before = df.count()
    df = df.dropDuplicates(["order_id"])
    logger.info(f"Dedup: removed {before - df.count()} duplicates")

    # Kolumny pochodne
    df = (df
        .withColumn("order_date",   F.to_date("ordered_at"))
        .withColumn("order_year",   F.year("ordered_at"))
        .withColumn("order_month",  F.month("ordered_at"))
        .withColumn("order_day",    F.dayofmonth("ordered_at"))
        .withColumn("processed_at", F.current_timestamp())
        .withColumn("etl_run_date", F.lit(RUN_DATE))
    )

    logger.info(f"Transform complete. Output rows: {df.count():,}")
    return df


orders_processed = transform_orders(orders_raw)

orders_enriched = (orders_processed
    .join(customers, on="customer_id", how="left")
)

logger.info(f"After JOIN: {orders_enriched.count():,} rows")


# -- Load --
now = datetime.utcnow()
output_path = (
    f"s3://{TARGET_BUCKET}/processed/orders_enriched/"
    f"year={now.year}/month={now.month:02d}/"
)

logger.info(f"Writing to: {output_path}")

(orders_enriched
    .repartition(4)
    .write
    .mode("overwrite")
    .parquet(output_path)
)

logger.info("ETL complete!")
job.commit()
