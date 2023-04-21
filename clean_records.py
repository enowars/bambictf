
# Install the Python Requests library:
# `pip install requests`
import os
import requests

AUTH_API_TOKEN = os.environ["HETZNERDNS_TOKEN"]
print(AUTH_API_TOKEN)

def list_records(ZoneID):
    # Get Records
    # GET https://dns.hetzner.com/api/v1/records

    try:
        response = requests.get(
            url="https://dns.hetzner.com/api/v1/records",
            params={
                "zone_id": ZoneID,
            },
            headers={
                "Auth-API-Token": AUTH_API_TOKEN,
            },
        )
        print('Response HTTP Status Code: {status_code}'.format(
            status_code=response.status_code))
        print('Response HTTP Response Body: {content}'.format(
            content=response.content))
    except requests.exceptions.RequestException:
        print('HTTP Request failed')

    return response.json()

def delete_record(RecordID):
    # Delete Record
    # DELETE https://dns.hetzner.com/api/v1/records/{RecordID}

    try:
        response = requests.delete(
            url=f"https://dns.hetzner.com/api/v1/records/{RecordID}",
            headers={
                "Auth-API-Token": AUTH_API_TOKEN,
            },
        )
        print('Response HTTP Status Code: {status_code}'.format(
            status_code=response.status_code))
        print('Response HTTP Response Body: {content}'.format(
            content=response.content))
    except requests.exceptions.RequestException:
        print('HTTP Request failed')


records = list_records("bambi.ovh")["records"]
print(records)

for record in records:
    print("RECORD", record["name"], "->", record["value"])
    #delete_record(record['id'])


confirm = input("Enter \"yes\" to delete all records")

if confirm.strip() == "yes":
    for record in records:
        print("DETLETING RECORD", record["name"], "->", record["value"])
        delete_record(record['id'])