using System.Security.Cryptography;

namespace RentalCamera.Api.Contracts;

public sealed class ContractPdfService(IWebHostEnvironment environment, IConfiguration configuration)
{
    private readonly string _directory = Path.GetFullPath(Path.Combine(
        environment.ContentRootPath,
        configuration.GetValue("ContractFiles:Directory", "App_Data/contracts")!));

    private readonly long _maximumBytes = Math.Clamp(
        configuration.GetValue("ContractFiles:MaximumMegabytes", 10), 1, 50) * 1024L * 1024L;

    public async Task<PdfSaveResult> SaveAsync(string contractId, Stream input, CancellationToken ct)
    {
        var destination = GetPath(contractId);
        Directory.CreateDirectory(_directory);
        var temporary = destination + "." + Guid.NewGuid().ToString("N") + ".tmp";

        try
        {
            long length = 0;
            string contentHash;
            await using (var output = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write,
                             FileShare.None, 81920, FileOptions.Asynchronous | FileOptions.SequentialScan))
            {
                using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
                var buffer = new byte[81920];
                var header = new byte[5];
                var headerLength = 0;

                while (true)
                {
                    var read = await input.ReadAsync(buffer.AsMemory(0, buffer.Length), ct);
                    if (read == 0) break;
                    length += read;
                    if (length > _maximumBytes)
                        throw new InvalidDataException($"Tệp PDF không được vượt quá {_maximumBytes / 1024 / 1024} MB.");

                    if (headerLength < header.Length)
                    {
                        var copy = Math.Min(header.Length - headerLength, read);
                        Buffer.BlockCopy(buffer, 0, header, headerLength, copy);
                        headerLength += copy;
                    }

                    hash.AppendData(buffer, 0, read);
                    await output.WriteAsync(buffer.AsMemory(0, read), ct);
                }

                if (length == 0 || headerLength < header.Length ||
                    header[0] != '%' || header[1] != 'P' || header[2] != 'D' ||
                    header[3] != 'F' || header[4] != '-')
                    throw new InvalidDataException("Dữ liệu tải lên không có định dạng PDF hợp lệ.");

                await output.FlushAsync(ct);
                contentHash = Convert.ToHexString(hash.GetHashAndReset());
            }
            File.Move(temporary, destination, true);
            return new PdfSaveResult(contentHash, length);
        }
        catch
        {
            if (File.Exists(temporary)) File.Delete(temporary);
            throw;
        }
    }

    public async Task<bool> VerifyAsync(string contractId, string expectedHash, CancellationToken ct)
    {
        var path = GetPath(contractId);
        if (!File.Exists(path) || string.IsNullOrWhiteSpace(expectedHash)) return false;
        var actualHash = await ComputeHashAsync(path, ct);
        return string.Equals(actualHash, expectedHash, StringComparison.OrdinalIgnoreCase);
    }

    public Stream OpenRead(string contractId) => new FileStream(GetPath(contractId), FileMode.Open,
        FileAccess.Read, FileShare.Read, 81920, FileOptions.Asynchronous | FileOptions.SequentialScan);

    public static async Task<string> ComputeHashAsync(string path, CancellationToken ct = default)
    {
        await using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read,
            81920, FileOptions.Asynchronous | FileOptions.SequentialScan);
        using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        var buffer = new byte[81920];
        while (true)
        {
            var read = await stream.ReadAsync(buffer.AsMemory(0, buffer.Length), ct);
            if (read == 0) break;
            hash.AppendData(buffer, 0, read);
        }
        return Convert.ToHexString(hash.GetHashAndReset());
    }

    private string GetPath(string contractId)
    {
        if (string.IsNullOrWhiteSpace(contractId) || contractId.Any(x => !char.IsLetterOrDigit(x) && x is not '-' and not '_'))
            throw new ArgumentException("Mã hợp đồng không hợp lệ.", nameof(contractId));
        return Path.Combine(_directory, contractId + ".pdf");
    }
}

public sealed record PdfSaveResult(string Sha256, long SizeBytes);
