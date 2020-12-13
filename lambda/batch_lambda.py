import sys
import datetime
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

table_name = "test"
read = "0.5"
output_prefix = "s3://log-bucket/test"  # s3 데이터 저장 위치
fmt = "glueparquet"  # batch 포맷
PARTITION = "snapshot"

args = getResolvedOptions(sys.argv, ['JOB_NAME'])

print("Table name:", table_name)
print("Read percentage:", read)
print("Output prefix:", output_prefix)
print("Format:", fmt)

# 저장 파티션 설정
date_str = datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S')
output = "%s/%s=%s" % (output_prefix, PARTITION, date_str)

sc = SparkContext()
glueContext = GlueContext(sc)

job = Job(glueContext)
job.init(args['JOB_NAME'], args)

table = glueContext.create_dynamic_frame.from_options(
    "dynamodb",
    connection_options={
        "dynamodb.input.tableName": table_name,
        "dynamodb.throughput.read.percent": read
    }
)

glueContext.write_dynamic_frame.from_options(
    frame=table,
    connection_type="s3",
    connection_options={
        "path": output
    },
    format=fmt,
    format_options={
        "compression": "snappy",  # 압축 형식
        "blockSize": "120MB",
        "pageSize": "10MB"
    },
    transformation_ctx="datasink"
)

job.commit()
