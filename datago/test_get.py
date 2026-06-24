import urllib.request
import json

url = 'http://127.0.0.1:8000/api/requests/'

try:
    response = urllib.request.urlopen(url)
    data = json.loads(response.read().decode())
    print(json.dumps(data, indent=2))
except Exception as e:
    print("ERROR:", str(e))
