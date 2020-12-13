# dynamoDB Example
resource "aws_dynamodb_table" "Dynamodb_test" {
  name = "test"
  read_capacity = 5
  write_capacity = 5
  hash_key = "pk"
  range_key = "sk"

}


// dynamoDB test table to s3
//iam
resource "aws_iam_role" "dynamodb_to_s3_role" {
  name = "dynamodb-to-s3-role"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "glue.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

# policy
# aws glue 기본 role
data "aws_iam_policy" "AWSGlueServiceRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_policy" "dynamodb_to_s3_policy" {
  name = "dynamodb-to-s3-policy"
  description = "dynampdb to s3 policy via glue"

  policy = <<EOF
{
  "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:DescribeTable",
                "dynamodb:Scan"
            ],
            "Resource": [
                "${aws_dynamodb_table.Dynamodb_test.arn}*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "${aws_s3_bucket.log_bucket.arn}/*" # 데이터 목적지 s3 arn
            ]
        }
    ]
}
EOF
}

//policy attach
resource "aws_iam_role_policy_attachment" "dynamodb_attach_policy" {
  policy_arn = aws_iam_policy.dynamodb_to_s3_policy.arn
  role = aws_iam_role.dynamodb_to_s3_role.name
}

resource "aws_iam_role_policy_attachment" "event_log_glue_ab_test_attach_aws_policy" {
  policy_arn = data.aws_iam_policy.AWSGlueServiceRole.arn
  role = aws_iam_role.dynamodb_to_s3_role.name
}

//job 생성
resource "aws_glue_job" "dynamodb_to_s3" {
  name = "dynamodb-to-s3"
  role_arn = aws_iam_role.dynamodb_to_s3_role.arn
  glue_version = "2.0"
  command {
    script_location = "s3://{}" # s3의 batch_lambda.py 위치 설정 또는 zip 사용가능
    python_version = 3
  }
}
