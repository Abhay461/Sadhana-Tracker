import urllib.request
import json

url = "https://plftorurxmtbzmdvttdm.supabase.co/rest/v1/profiles?select=*&limit=1"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBsZnRvcnVyeG10YnptZHZ0dGRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxOTU4OTcsImV4cCI6MjA4OTc3MTg5N30.uFuYV62UEVn_lJxPJKU3uLGRsf695njDiRI4h4NmEI0",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBsZnRvcnVyeG10YnptZHZ0dGRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxOTU4OTcsImV4cCI6MjA4OTc3MTg5N30.uFuYV62UEVn_lJxPJKU3uLGRsf695njDiRI4h4NmEI0"
}

req = urllib.request.Request(url, headers=headers)
try:
    with urllib.request.urlopen(req) as response:
        data = response.read().decode('utf-8')
        profiles = json.loads(data)
        if profiles:
            print("Columns in profiles table:")
            for k in profiles[0].keys():
                print(f"  - {k} (type of value: {type(profiles[0][k]).__name__})")
            print("Sample profile data:", profiles[0])
        else:
            print("Profiles table is empty.")
except Exception as e:
    print("Error querying database:", e)
