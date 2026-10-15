import requests
import json
import uuid
import datetime

base_url = 'http://localhost:5000'
ch = 'CH001'
dm = 'DONG001'
now = datetime.datetime.now()
ngayBatDau = (now + datetime.timedelta(days=1)).strftime('%Y-%m-%dT10:00:00')
ngayKetThuc = (now + datetime.timedelta(days=3)).strftime('%Y-%m-%dT10:00:00')

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
print('Tao giu cho:', r1.status_code, r1.text)
hold_id = r1.json().get('maGiuCho')

print('\n--- GOI /api/lich-trong/thang KHONG KEM TOKEN ---')
r_notoken = requests.get(f'{base_url}/api/lich-trong/thang', params={
    'maCuaHang': ch, 'maDongMay': dm, 'soLuong': 1, 'thang': now.month, 'nam': now.year, 'maGiuCho': hold_id
})
print('Khong token:', r_notoken.status_code, r_notoken.text)

print('\n--- GOI /api/lich-trong/thang CO TOKEN ---')
r_token = requests.get(f'{base_url}/api/lich-trong/thang', params={
    'maCuaHang': ch, 'maDongMay': dm, 'soLuong': 1, 'thang': now.month, 'nam': now.year, 'maGiuCho': hold_id
}, headers={'Authorization': f'Bearer {token}'})
print('Co token:', r_token.status_code, r_token.text[:200], '...')
