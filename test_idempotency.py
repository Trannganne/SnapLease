import asyncio
import aiohttp
import time

async def make_request(session, url, data, headers, i):
    start_time = time.time()
    try:
        async with session.post(url, json=data, headers=headers) as response:
            resp_data = await response.json()
            status = response.status
            end_time = time.time()
            print(f"Request {i} completed in {end_time - start_time:.4f}s with status {status}: {resp_data}")
            return status, resp_data
    except Exception as e:
        print(f"Request {i} failed: {e}")
        return None, None

async def test_concurrent_payments(contract_id, token):
    url = f"http://localhost:5000/api/hop-dong/{contract_id}/thanh-toan-coc"
    data = {
        "phuongThuc": "TIEN_MAT",
        "noiDungChuyenKhoan": ""
    }
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }

    print("Testing 5 concurrent requests...")
    async with aiohttp.ClientSession() as session:
        tasks = [make_request(session, url, data, headers, i) for i in range(5)]
        results = await asyncio.gather(*tasks)
        print("Results:", results)

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 3:
        print("Sử dụng: python test_idempotency.py <CONTRACT_ID> <JWT_TOKEN>")
        sys.exit(1)

    contract_id = sys.argv[1]
    token = sys.argv[2]
    asyncio.run(test_concurrent_payments(contract_id, token))
