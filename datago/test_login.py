import urllib.request
import json
import urllib.error

url = 'http://127.0.0.1:8000/api/auth/login/'
data = json.dumps({'username': 'joni@gmail.com', 'password': 'supersecurepassword'}).encode()
headers = {'Content-Type': 'application/json'}
req = urllib.request.Request(url, data=data, headers=headers)

try:
    response = urllib.request.urlopen(req)
    print("STATUS:", response.status)
    print(response.read().decode())
except urllib.error.HTTPError as e:
    print("HTTP ERROR:", e.code)
    print(e.read().decode())
except Exception as e:
    print("ERROR:", str(e))
