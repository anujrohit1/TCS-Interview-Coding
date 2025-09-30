import json
import os
import sys
import requests

def main():
    filename = "example.json"

    # Step 1: Read and validate JSON
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"File {filename} not found.")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Invalid JSON in {filename}: {e}")
        sys.exit(1)

    # Step 2: Filter objects with private == false
    # Assuming data is a list or dict of objects
    # We need to handle both cases gracefully
    if isinstance(data, list):
        filtered_data = [obj for obj in data if isinstance(obj, dict) and obj.get("private") == False]
    elif isinstance(data, dict):
        # Filter dict items where value is an object with private == False
        filtered_data = {k: v for k, v in data.items() if isinstance(v, dict) and v.get("private") == False}
    else:
        print("JSON root structure is not a list or dict.")
        sys.exit(1)

    # Step 3 & 4: POST filtered JSON to the web service
    # Assuming the web service base URL (change if needed)
    base_url = "https://example.com"
    endpoint = "/service/generate"
    url = base_url + endpoint

    try:
        headers = {"Content-Type": "application/json"}
        response = requests.post(url, json=filtered_data, headers=headers)
        response.raise_for_status()
    except requests.RequestException as e:
        print(f"Failed to make POST request: {e}")
        sys.exit(1)

    # Step 5: Process response JSON
    try:
        response_data = response.json()
    except json.JSONDecodeError:
        print("Response is not valid JSON.")
        sys.exit(1)

    # Print keys with child attribute "valid" == True
    if isinstance(response_data, dict):
        for key, value in response_data.items():
            if isinstance(value, dict) and value.get("valid") is True:
                print(key)
    else:
        print("Response JSON is not an object/dict.")

if __name__ == "__main__":
    main()


    # Note: We need to replace "https://example.com" with the simple web service URL, which can be created using flask app in python.
    # Note: As the code uses the requests library, which is standard for HTTP in Python. So, we have installed it via pip.
