using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;

namespace RentalCamera.Api.Infrastructure;

public static class TransactionLock
{
    // All callers must already own a DB transaction. Cross-process, released on rollback/commit.
    public static Task AcquireAsync(RentalCameraContext db, string resource, CancellationToken ct) =>
        db.Database.ExecuteSqlRawAsync("""
            DECLARE @r int;
            EXEC @r=sys.sp_getapplock @Resource=@resource, @LockMode='Exclusive',
                @LockOwner='Transaction', @LockTimeout=10000;
            IF @r < 0 THROW 51001, 'Concurrent operation; reload and retry.', 1;
            """, [new SqlParameter("@resource", resource)], ct);
}
