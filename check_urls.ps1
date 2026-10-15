$urls = @(
    "https://res.cloudinary.com/rqdym8rq/image/upload/canon-r6-1.jpg",
    "https://res.cloudinary.com/rqdym8rq/image/upload/canon-r6-2.jpg",
    "https://res.cloudinary.com/rqdym8rq/image/upload/sony-a7iii.jpg",
    "https://res.cloudinary.com/rqdym8rq/image/upload/canon-rf2470.jpg",
    "https://res.cloudinary.com/rqdym8rq/image/upload/nikon-z6ii.jpg"
)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
foreach ($url in $urls) {
    try {
        $request = [System.Net.WebRequest]::Create($url)
        $request.Method = "HEAD"
        $response = $request.GetResponse()
        Write-Output "OK: $url"
        $response.Close()
    } catch {
        Write-Output "FAIL: $url - $($_.Exception.Message)"
    }
}
