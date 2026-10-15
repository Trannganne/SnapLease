import requests
import json
import uuid
import datetime
import threading
import sys
import io
import time

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
base_url = 'http://localhost:5000'
ch = 'CH001'
dm = 'DONG001'
now = datetime.datetime.now()
ngayBatDau = (now + datetime.timedelta(days=100)).strftime('%Y-%m-%dT10:00:00')
ngayKetThuc = (now + datetime.timedelta(days=103)).strftime('%Y-%m-%dT10:00:00')

def register_and_login(username):
    time.sleep(1.5)
    requests.post(f'{base_url}/api/auth/register', json={
        'TenDangNhap': username,
        'MatKhau': 'Test_12345!',
        'SoDienThoai': str(uuid.uuid4().int)[:10]
    })
    res = requests.post(f'{base_url}/api/auth/login', json={
        'TenDangNhap': username,
        'MatKhau': 'Test_12345!'
    })
    if res.status_code != 200:
        print('Login fail:', res.status_code, res.text)
        return ''
    return res.json()['accessToken']

avail = requests.get(f'{base_url}/api/lich-trong', params={
    'maCuaHang': ch, 'maDongMay': dm, 'ngayBatDau': ngayBatDau, 'ngayKetThuc': ngayKetThuc
}).json()['soLuongConTrong']
print(f'Available devices: {avail}')

if avail > 0:
    token2 = register_and_login('testuser_' + str(uuid.uuid4())[:8])
    token3 = register_and_login('testuser_' + str(uuid.uuid4())[:8])

    payload_conc = {
        'MaCuaHang': ch,
        'MaDongMay': dm,
        'SoLuong': avail,
        'NgayBatDau': ngayBatDau,
        'NgayKetThuc': ngayKetThuc
    }

    results = []
    def book(token, idx):
        if not token:
            results.append((idx, 'NO_TOKEN', ''))
            return
        h = {'Authorization': f'Bearer {token}', 'Idempotency-Key': str(uuid.uuid4())}
        res = requests.post(f'{base_url}/api/giu-cho/thue-ngay', json=payload_conc, headers=h)
        results.append((idx, res.status_code, res.text))

    t1 = threading.Thread(target=book, args=(token2, 1))
    t2 = threading.Thread(target=book, args=(token3, 2))
    t1.start()
    t2.start()
    t1.join()
    t2.join()

    print('Concurrency results:')
    for r in results:
        print(f'Thread {r[0]}: {r[1]} - {r[2]}')
