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

token1 = register_and_login('testuser_' + str(uuid.uuid4())[:8])
headers = {'Authorization': f'Bearer {token1}', 'Idempotency-Key': str(uuid.uuid4())}

print('--- TEST 1: TAO GIU CHO ---')
payload = {
    'MaCuaHang': ch,
    'MaDongMay': dm,
    'SoLuong': 1,
    'NgayBatDau': ngayBatDau,
    'NgayKetThuc': ngayKetThuc
}
r1 = requests.post(f'{base_url}/api/giu-cho/thue-ngay', json=payload, headers=headers)
print('Tao giu cho:', r1.status_code, r1.text)
hold_id = r1.json().get('maGiuCho') if r1.status_code in [200, 201] else ''

print('\n--- TEST 2: RETRY CUNG KEY ---')
r2 = requests.post(f'{base_url}/api/giu-cho/thue-ngay', json=payload, headers=headers)
print('Retry:', r2.status_code, r2.text)

print('\n--- TEST 3: KHOI PHUC LUU LUOT (ACTIVE) ---')
r3 = requests.get(f'{base_url}/api/giu-cho/cua-toi/active', headers={'Authorization': f'Bearer {token1}'})
print('Active hold:', r3.status_code, r3.text)

print('\n--- TEST 4: HUY GIU CHO ---')
r4 = requests.post(f'{base_url}/api/giu-cho/{hold_id}/huy', headers={'Authorization': f'Bearer {token1}'})
print('Cancel:', r4.status_code, r4.text)

print('\n--- TEST 5: KHOI PHUC SAU KHI HUY (KHONG CON ACTIVE) ---')
r5 = requests.get(f'{base_url}/api/giu-cho/cua-toi/active', headers={'Authorization': f'Bearer {token1}'})
print('Active hold after cancel:', r5.status_code, r5.text)

print('\n--- TEST 6: CONCURRENCY ---')
time.sleep(1)
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
