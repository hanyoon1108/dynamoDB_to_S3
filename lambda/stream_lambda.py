import os, json, base64, datetime
import boto3
firehose = boto3.client('firehose')

# 데이터 형 체크
def check_data_type(data):
    # string 데이터 형
    if list(data.keys())[0] is "S":
        return data["S"]
    # number 데이터 형
    elif list(data.keys())[0] is "N":
        return float(data["N"]) if float(data["N"]) % 1 != 0 else int(data["N"])
    # long 데이터 형
    elif list(data.keys())[0] is "L":
        return [check_data_type(i) for i in data['L']]

def gen_firehose_data(event_list):
    kfh_data_list = []
    for record in event_list:
        event_name = record['eventName']
        # 새로 추가된 데이터 처리
        if event_name == "INSERT":
            kfh_data = {}
            keys = record['dynamodb']['Keys']

            # 키 데이터 반환
            for key in keys.keys():
                kfh_data[key] = check_data_type(keys[key])

            new_data = record['dynamodb']['NewImage']
            for new in new_data.keys():
                kfh_data[new] = check_data_type(new_data[new])

            # 데이터 끝에 \n로 구분해야 모든 데이터 확인 가능 아니면 첫번쨰 데이터만 읽음
            kfh_data_list.append({'Data': json.dumps(kfh_data, ensure_ascii=False) + '\n'})

    return kfh_data_list

def lambda_handler(event, context):
    firehose_data_list = gen_firehose_data(event['Records'])
    if not firehose_data_list:
        return "No insert data"

    response = firehose.put_record_batch(
        DeliveryStreamName=os.environ['DeliveryStreamName'],
        Records=firehose_data_list
    )
    return 'Successfully processed {} records.'.format(len(firehose_data_list))