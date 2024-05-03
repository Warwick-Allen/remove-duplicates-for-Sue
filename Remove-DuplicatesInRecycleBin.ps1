# This reads the output file of the Czkawka duplicate finder.
#
# Copywrite Warwick Allen, 2024

$resultJsonFile = 'C:\Users\Sue Wickison\results_duplicates_compact.json'
$logFileBase = 'C:\Users\Sue Wickison\Remove-DuplicatesInRecycleBin'
$timeStamp = ((Get-Date).ToString('yyyyMMdd-hhmmss'))
$transcriptFile = $logFileBase + '.' + $timestamp + '.log'

Start-Transcript -Path $transcriptFile

$results = Get-Content -Raw $resultJsonFile | ConvertFrom-Json | Get-ObjectMember

$volumeDeleted = 0
foreach ($result in $results) {
  foreach ($files in $result.Value) {
    foreach ($file in $files) {
      if (
        $file.path -imatch '^C:\\\$Recycle.Bin\\'
      ) {
        $volumeDeleted += $file.size
        Remove-Item -Verbose -Path $file.path
      }
    }
  }
}

"$($volumeDeleted/(1 -shl 30)) GiB deleted." | Write-Host
Stop-Transcript
