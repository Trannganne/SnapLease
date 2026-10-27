using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;

namespace RentalCamera.Api.Notifications;

public sealed class FirebaseNotificationSender
{
    private readonly RentalCameraContext db;
    private readonly FirebaseMessaging? messaging;
    private readonly bool fake;
    private readonly ILogger<FirebaseNotificationSender> logger;

    public FirebaseNotificationSender(
        RentalCameraContext db,
        IServiceProvider services,
        IConfiguration configuration,
        ILogger<FirebaseNotificationSender> logger)
    {
        this.db = db;
        fake = configuration["Schema33Trial:ProviderMode"] == "Fake";
        messaging = fake ? null : FirebaseMessaging.GetMessaging(services.GetRequiredService<FirebaseApp>());
        this.logger = logger;
    }

    public async Task<FcmSendResult> SendToAccountAsync(
        string accountId,
        string title,
        string body,
        string eventCode,
        string? targetType,
        string? targetId,
        CancellationToken ct)
    {
        if (fake) return new FcmSendResult(0,0,0); // Inbox/outbox remain authoritative; no transport delivery claim.
        var transport = messaging ?? throw new InvalidOperationException("FCM transport chua san sang.");
        var tokenRows = await db.FcmDeviceToken
            .Where(x => x.MaTaiKhoan == accountId && x.IsActive)
            .OrderBy(x => x.CreatedAt)
            .ToListAsync(ct);

        if (tokenRows.Count == 0)
        {
            return new FcmSendResult(0, 0, 0);
        }

        var data = new Dictionary<string, string>
        {
            ["eventCode"] = eventCode
        };

        if (!string.IsNullOrWhiteSpace(targetType))
        {
            data["targetType"] = targetType;
        }

        if (!string.IsNullOrWhiteSpace(targetId))
        {
            data["targetId"] = targetId;
        }

        var successCount = 0;
        var failureCount = 0;
        var changedTokenState = false;

        foreach (var tokenChunk in tokenRows.Chunk(500))
        {
            var rows = tokenChunk.ToArray();

            var message = new MulticastMessage
            {
                Fids = rows.Select(x => x.Token).ToList(),
                Notification = new Notification
                {
                    Title = title,
                    Body = body
                },
                Data = data
            };

            try
            {
                var response = await transport
                    .SendEachForMulticastAsync(message, ct);

                successCount += response.SuccessCount;
                failureCount += response.FailureCount;

                for (var index = 0; index < response.Responses.Count; index++)
                {
                    var sendResponse = response.Responses[index];

                    if (!sendResponse.IsSuccess &&
                        sendResponse.Exception?.MessagingErrorCode ==
                        MessagingErrorCode.Unregistered)
                    {
                        rows[index].IsActive = false;
                        rows[index].UpdatedAt = DateTime.UtcNow;
                        changedTokenState = true;
                    }
                }
            }
            catch (FirebaseMessagingException ex)
            {
                failureCount += rows.Length;

                logger.LogError(
                    ex,
                    "Không thể gửi FCM cho tài khoản {AccountId}.",
                    accountId);
            }
        }

        if (changedTokenState)
        {
            await db.SaveChangesAsync(ct);
        }

        logger.LogInformation(
            "FCM tài khoản {AccountId}: thử {Attempted}, thành công {Success}, thất bại {Failure}.",
            accountId,
            tokenRows.Count,
            successCount,
            failureCount);

        return new FcmSendResult(
            tokenRows.Count,
            successCount,
            failureCount);
    }
}

public sealed record FcmSendResult(
    int Attempted,
    int Success,
    int Failure);