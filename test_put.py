import requests
import json
import uuid
import datetime

base_url = 'http://localhost:5000'
ch = 'CH001'
dm = 'DONG001'
now = datetime.datetime.now()
ngayBatDau = (now + datetime.timedelta(days=10)).strftime('%Y-%m-%dT10:00:00')
ngayKetThuc = (now + datetime.timedelta(days=13)).strftime('%Y-%m-%dT10:00:00')
ngayKetThuc2 = (now + datetime.timedelta(days=14)).strftime('%Y-%m-%dT10:00:00')

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
    return res.json()['accessToken']

token = register_and_login('testuser_' + str(uuid.uuid4())[:8])
headers = {'Authorization': f'Bearer {token}', 'Idempotency-Key': str(uuid.uuid4())}

print('--- TAO GIU CHO ---')
payload = {
    'MaCuaHang': ch,
    'MaDongMay': dm,
    'SoLuong': 1,
    'NgayBatDau': ngayBatDau,
    'NgayKetThuc': ngayKetThuc
}
r1 = requests.post(f'{base_url}/api/giu-cho/thue-ngay', json=payload, headers=headers)
print('Tao giu cho status:', r1.status_code)
js = r1.json()
hold_id = js.get('maGiuCho')
het_han = js.get('hetHanLuc')
print(f"Created Hold ID: {hold_id}, HetHanLuc: {het_han}")

print('\n--- GOI /api/giu-cho/{id} DE CAP NHAT ---')
r_update = requests.put(f'{base_url}/api/giu-cho/{hold_id}', json={
    'maCuaHang': ch, 'maDongMay': dm, 'soLuong': 1, 'ngayBatDau': ngayBatDau, 'ngayKetThuc': ngayKetThuc2
}, headers={'Authorization': f'Bearer {token}'})

print('Update Status:', r_update.status_code)
update_js = r_update.json()
print(f"Updated Hold ID: {update_js.get('maGiuCho')}, HetHanLuc: {update_js.get('hetHanLuc')}")
if het_han == update_js.get('hetHanLuc'):
    print("SUCCESS: HetHanLuc did not change!")
else:
    print("WARNING: HetHanLuc CHANGED!")
