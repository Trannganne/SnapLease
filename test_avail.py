import requests
import json
import uuid
import datetime
import threading
import sys
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
base_url = 'http://localhost:5000'
ch = 'CH001'
dm = 'DONG001'
now = datetime.datetime.now()
ngayBatDau = (now + datetime.timedelta(days=100)).strftime('%Y-%m-%dT10:00:00')
ngayKetThuc = (now + datetime.timedelta(days=103)).strftime('%Y-%m-%dT10:00:00')

print(f'Checking availability for {ngayBatDau} to {ngayKetThuc}')
avail = requests.get(f'{base_url}/api/lich-trong', params={
    'maCuaHang': ch, 'maDongMay': dm, 'ngayBatDau': ngayBatDau, 'ngayKetThuc': ngayKetThuc
}).text
print(f'Available devices: {avail}')
