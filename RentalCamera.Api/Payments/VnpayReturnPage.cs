using System.Net;

namespace RentalCamera.Api.Payments;

public static class VnpayReturnPage
{
    public static string Build(string paymentId, string contractId, string responseCode)
    {
        var gatewayAccepted = responseCode == "00";
        var heading = gatewayAccepted
            ? "Đã ghi nhận kết quả thanh toán"
            : "Giao dịch chưa hoàn tất";
        var detail = gatewayAccepted
            ? "VNPAY đã chuyển kết quả về SnapLease. Trạng thái chính thức sẽ được cập nhật qua hệ thống đối soát."
            : "Giao dịch đã bị hủy hoặc chưa thành công. Bạn có thể quay lại ứng dụng để kiểm tra và thử lại.";
        var badgeClass = gatewayAccepted ? "success" : "warning";

        return $$"""
            <!doctype html>
            <html lang="vi">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width,initial-scale=1">
              <title>{{WebUtility.HtmlEncode(heading)}} - SnapLease</title>
              <style>
                :root{color-scheme:light;font-family:system-ui,-apple-system,"Segoe UI",sans-serif;color:#172033;background:#f5f7fb}
                body{margin:0;min-height:100vh;display:grid;place-items:center;padding:24px;box-sizing:border-box}
                main{width:min(440px,100%);background:#fff;border-radius:20px;padding:28px;box-shadow:0 16px 48px #1831531c;text-align:center}
                .mark{width:64px;height:64px;margin:0 auto 18px;border-radius:50%;display:grid;place-items:center;font-size:32px;font-weight:700}
                .success{color:#087a48;background:#e5f8ef}.warning{color:#9a5a00;background:#fff3d6}
                h1{font-size:24px;line-height:1.25;margin:0 0 12px}p{line-height:1.55;color:#526077;margin:0 0 18px}
                dl{margin:0 0 22px;padding:14px 16px;border-radius:12px;background:#f7f8fb;text-align:left}
                dt{font-size:12px;color:#738096;margin-top:8px}dt:first-child{margin-top:0}dd{margin:2px 0 0;font-weight:650;overflow-wrap:anywhere}
                button{width:100%;border:0;border-radius:12px;background:#2457d6;color:white;padding:14px 18px;font-size:16px;font-weight:700;cursor:pointer}
                small{display:block;color:#7a869b;margin-top:14px;line-height:1.45}
              </style>
            </head>
            <body>
              <main>
                <div class="mark {{badgeClass}}" aria-hidden="true">{{(gatewayAccepted ? "✓" : "!")}}</div>
                <h1>{{WebUtility.HtmlEncode(heading)}}</h1>
                <p>{{WebUtility.HtmlEncode(detail)}}</p>
                <dl>
                  <dt>Mã thanh toán</dt><dd>{{WebUtility.HtmlEncode(paymentId)}}</dd>
                  <dt>Mã hợp đồng</dt><dd>{{WebUtility.HtmlEncode(contractId)}}</dd>
                </dl>
                <button type="button" onclick="history.length>1?history.back():window.close()">Quay lại ứng dụng</button>
                <small>Nếu ứng dụng không tự mở, hãy đóng trang này và mở lại SnapLease để xem trạng thái mới nhất.</small>
              </main>
            </body>
            </html>
            """;
    }
}
