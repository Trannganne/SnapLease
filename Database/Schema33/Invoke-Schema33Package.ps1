[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$SchemaPackageDirectory,
 [ValidateSet('Review','Preflight','Schema','CatalogSeed','VerifySchema','VerifyData')][string]$Mode='Review',
 [switch]$ExecuteAfterDbApproval,
 [string]$ApprovalFile,
 [string]$ReviewedManifestSha256,
 [string]$EvidenceDirectory
)
$ErrorActionPreference='Stop'
$base=[System.IO.Path]::GetFullPath($SchemaPackageDirectory)
function Hash-Bytes([byte[]]$Bytes){$h=[System.Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($h.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}finally{$h.Dispose()}}
function Safe-Path([string]$Relative){
 if([System.IO.Path]::IsPathRooted($Relative)){throw 'Relative package path required'}
 $p=[System.IO.Path]::GetFullPath((Join-Path $base $Relative))
 if(!$p.StartsWith($base+[System.IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Package path escaped'}
 $cursor=Get-Item -LiteralPath $p
 while($null -ne $cursor){if(($cursor.Attributes -band [System.IO.FileAttributes]::ReparsePoint)-ne 0){throw 'Reparse path refused'};$cursor=$cursor.Parent}
 return $p
}
$manifestPath=Join-Path $base 'package-manifest.json'
$manifestBytes=[System.IO.File]::ReadAllBytes($manifestPath)
$manifestHash=Hash-Bytes $manifestBytes
$manifest=[System.Text.Encoding]::UTF8.GetString($manifestBytes)|ConvertFrom-Json
foreach($f in $manifest.files){$p=Safe-Path $f.path;if((Hash-Bytes ([System.IO.File]::ReadAllBytes($p))) -cne $f.sha256){throw ('File hash mismatch: '+$f.path)}}
$stage=@{Preflight='00_preflight.sql';Schema='01_schema33.sql';CatalogSeed='02_seed_catalog.sql';VerifySchema='04_verify_schema.sql';VerifyData='05_verify_seed_catalog.sql'}
if(!$ExecuteAfterDbApproval -or $Mode -eq 'Review'){
 [pscustomobject]@{Status='FILES_VERIFIED_ONLY_NO_SQL';Mode=$Mode;ManifestSha256=$manifestHash;Files=$manifest.files.Count;PlannedSql=$stage[$Mode];Database='RentalCameraDb30_Test';DatabaseConnected=$false}|ConvertTo-Json
 return
}
if($Mode -in @('Schema','CatalogSeed') -and $manifest.Status -cne 'REVIEWED_READY_FOR_DATABASE'){throw 'Package files are sealed but runtime EF/definition checks are still pending; do not mutate the database.'}
if([string]::IsNullOrWhiteSpace($ApprovalFile) -or $ReviewedManifestSha256 -cnotmatch '^[a-f0-9]{64}$' -or $ReviewedManifestSha256 -cne $manifestHash){throw 'Exact reviewed manifest hash and separate approval file required'}
$approval=Get-Content -LiteralPath $ApprovalFile -Raw -Encoding UTF8|ConvertFrom-Json
if($approval.DatabasePackageApproved -ne $true -or $approval.PreDatabaseChecksAccepted -ne $true -or $approval.ExpectedDatabase -cne 'RentalCameraDb30_Test' -or $approval.Environment -cne 'Schema33Trial' -or $approval.AllowedOperations -cnotcontains $Mode){throw 'Operation not explicitly approved'}
if([string]::IsNullOrWhiteSpace($approval.ExpectedServerName) -or [string]::IsNullOrWhiteSpace($approval.ExpectedDataSource)){throw 'Fresh server/data-source binding required'}
if([string]::IsNullOrWhiteSpace($EvidenceDirectory)){throw 'New private evidence directory required'}
$evidence=[System.IO.Path]::GetFullPath($EvidenceDirectory)
if(Test-Path -LiteralPath $evidence){throw 'Evidence directory already exists; do not overwrite'}
# The connection is read only after all file/approval checks. No file/config fallback exists.
$privateConnection=[Environment]::GetEnvironmentVariable('SNAPLEASE33_SQL_CONNECTION','Process')
if([string]::IsNullOrWhiteSpace($privateConnection)){throw 'Private connection environment variable missing'}
$binding=[System.Data.SqlClient.SqlConnectionStringBuilder]::new($privateConnection)
if($binding.InitialCatalog -cne $approval.ExpectedDatabase -or $binding.DataSource -ine $approval.ExpectedDataSource -or ![string]::IsNullOrWhiteSpace($binding.AttachDBFilename)){throw 'Connection target does not match approved scope'}
$sqlFile=$stage[$Mode];$sqlPath=Safe-Path $sqlFile
$sqlBytes=[System.IO.File]::ReadAllBytes($sqlPath);$sqlHash=Hash-Bytes $sqlBytes
if(!($manifest.files|Where-Object {$_.path -ceq $sqlFile -and $_.sha256 -ceq $sqlHash})){throw 'SQL file not in approved manifest'}
New-Item -ItemType Directory -Path $evidence -ErrorAction Stop|Out-Null
$report=[ordered]@{StartedUtc=[DateTime]::UtcNow.ToString('o');Mode=$Mode;ManifestSha256=$manifestHash;SqlFile=$sqlFile;SqlSha256=$sqlHash;Status='STARTED';NoAutomaticReplayOrCleanup=$true}
$connection=[System.Data.SqlClient.SqlConnection]::new($privateConnection)
try{
 $connection.Open()
 $probe=$connection.CreateCommand();$probe.CommandText="SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),DB_NAME(),@@TRANCOUNT";$reader=$probe.ExecuteReader()
 if(!$reader.Read() -or $reader.GetString(0) -cne $approval.ExpectedServerName -or $reader.GetString(1) -cne $approval.ExpectedDatabase -or $reader.GetInt32(2) -ne 0){$reader.Close();throw 'Fresh SQL server/database/transaction guard differs'}
 $report.Server=$reader.GetString(0);$report.Database=$reader.GetString(1);$reader.Close();$probe.Dispose()
 foreach($entry in @{'Schema33.ExpectedDatabase'=$approval.ExpectedDatabase;'Schema33.ExpectedServer'=$approval.ExpectedServerName;'Schema33.Environment'='Schema33Trial';'Schema33.DatabasePackageApproved'=1;'Schema33.ReviewedFileSha256'=$sqlHash;'Schema33.CalculatedFileSha256'=$sqlHash}.GetEnumerator()){
  $c=$connection.CreateCommand();$c.CommandText='EXEC sys.sp_set_session_context @key=@k,@value=@v';[void]$c.Parameters.AddWithValue('@k',$entry.Key);[void]$c.Parameters.AddWithValue('@v',$entry.Value);[void]$c.ExecuteNonQuery();$c.Dispose()
 }
 $cmd=$connection.CreateCommand();$cmd.CommandTimeout=120;$cmd.CommandText=[System.Text.Encoding]::UTF8.GetString($sqlBytes)
 $set=[System.Data.DataSet]::new();$adapter=[System.Data.SqlClient.SqlDataAdapter]::new($cmd);[void]$adapter.Fill($set)
 $sizes=@();$issues=0;$resultIndex=0
 foreach($table in $set.Tables){
  $resultIndex++
  $rows=@(foreach($row in $table.Rows){$values=[ordered]@{};foreach($column in $table.Columns){$value=$row[$column.ColumnName];$values[$column.ColumnName]=if($value -is [System.DBNull]){$null}else{$value}};[pscustomobject]$values})
  [System.IO.File]::WriteAllText((Join-Path $evidence ('result-set-'+$resultIndex+'.json')),(ConvertTo-Json -InputObject $rows -Depth 20),[System.Text.UTF8Encoding]::new($false))
  $sizes+=@{Rows=$table.Rows.Count;Columns=@($table.Columns|ForEach-Object {$_.ColumnName})}
  if($table.Columns.Contains('DefinitionsJson') -and $table.Rows.Count -eq 1){[System.IO.File]::WriteAllText((Join-Path $evidence 'metadata-definitions.json'),[string]$table.Rows[0]['DefinitionsJson'],[System.Text.UTF8Encoding]::new($false))}
  if($table.Columns.Contains('Issue')){$issues+=$table.Rows.Count}
 }
 $report.ResultSets=$sizes;$report.IssueRows=$issues
 if($issues -gt 0){$report.Status='VERIFY_ISSUES_FOUND'}elseif($Mode -eq 'VerifySchema'){$report.Status='STRUCTURE_MATCH_DEFINITION_AST_COMPARE_STILL_REQUIRED'}else{$report.Status='COMMAND_COMPLETED_REVIEW_RESULTS'}
 $adapter.Dispose();$cmd.Dispose()
}catch{
 $report.Status='STOP_KNOWN_ERROR_OR_UNKNOWN_WRITE_RESULT_NO_REPLAY'
 $report.ErrorType=$_.Exception.GetType().Name
 if($_.Exception -is [System.Data.SqlClient.SqlException]){$report.SqlErrorNumber=$_.Exception.Number}
 # No connection string, SQL credentials, full exception/body or private config is printed.
 throw 'Database operation stopped; inspect sanitized evidence and read metadata before any retry.'
}finally{
 if($connection.State -eq [System.Data.ConnectionState]::Open){try{$c=$connection.CreateCommand();$c.CommandText='SELECT @@TRANCOUNT';$report.TransactionCountBeforeClose=$c.ExecuteScalar();$c.Dispose()}catch{$report.TransactionCountBeforeClose='UNKNOWN'}}
 $connection.Dispose();$report.FinishedUtc=[DateTime]::UtcNow.ToString('o')
 [System.IO.File]::WriteAllText((Join-Path $evidence 'result.json'),($report|ConvertTo-Json -Depth 12),[System.Text.UTF8Encoding]::new($false))
}
[pscustomobject]$report|ConvertTo-Json -Depth 12
if($report.IssueRows -gt 0){throw 'Verification issue rows require review'}
