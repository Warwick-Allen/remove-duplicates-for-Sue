# This reads the output file of the Czkawka duplicate finder.
#
# Needs to be run as an administrator (to create the symlinks).
#
# Copywrite Warwick Allen, 2024

$duplicatesFolder = 'C:\Users\Sue Wickison\Duplicates'
$resultJsonFile = 'C:\Users\warwi_b\Downloads\results_duplicates\results_duplicates_compact.json'
$logFileBase = 'C:\Users\Sue Wickison\Duplicates\Remove-DuplicatesForSue'
$timeStamp = ((Get-Date).ToString('yyyyMMdd-hhmmss'))
$logFile = $logFileBase + '.' + $timestamp + '.txt'
$transcriptFile = $logFileBase + '.' + $timestamp + '.log'

Start-Transcript -Path $transcriptFile

# helper to turn PSCustomObject into a list of key/value pairs
function Get-ObjectMember {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [PSCustomObject]$obj
    )
    $obj | Get-Member -MemberType NoteProperty | ForEach-Object {
        $key = $_.Name
        [PSCustomObject]@{Key = $key; Value = $obj."$key"}
    }
}

# Only consider files having these extentions.
$extentionsRegex = '\.(' + (@(
    'db'  , 'doc' , 'docx',
    'emf' , 'exe' , 'gif' ,
    'jpeg', 'jpg' , 'jrs' ,
    'js'  , 'json', 'jtx' ,
    'log' , 'm4a' ,#'mht' ,
    'mov' , 'mp3' , 'mp4' ,
    'msi' , 'mts' , 'nef' ,
    'pdf' , 'pma' , 'png' ,
    'ppt' , 'pptx', 'psd' ,
    'pst' , 'tif' , 'tmp' ,
    'vob' , 'wma' , 'zip'
  ) -join '|') + ')$'

$results = Get-Content -Raw $resultJsonFile | ConvertFrom-Json | Get-ObjectMember
$duplicatesByHash = @{}
foreach ($result in $results) {
  foreach ($files in $result.Value) {
    foreach ($file in $files) {
      if (
        ($file.path -notmatch '(^NTUSER|\\AppData\\)') -and
        ($file.path -imatch $extentionsRegex)
      ) {
        $hash = $file.hash
        if (!$duplicatesByHash.ContainsKey($hash)) {
         $duplicatesByHash[$hash] = New-Object System.Collections.Generic.List[System.Object]
        }
        ($duplicatesByHash[$hash]) += $file
      }
    }
  }
}

$volumeMoved = 0
(@(
  "Date Time",
  "Removed File",
  "Retained File",
  "Hash"
 ) -join "`t") | Tee-Object -FilePath $logFile
$duplicatesByHash.Values |
  ForEach-Object {
    $keepFilePath = (
      ($_.path -notmatch '( - Copy\\|\\old files\\| \(\d\)(\\|\.\w{3}$))') |
      Select-Object -First 1
    )
    ($_.path -notmatch '( - Copy\\|\\old files\\| \(\d\)(\\|\.\w{3}$))') | ConvertTo-Json | Write-Host
    if (!$keepFilePath -or $keepFilePath.GetType().Name -eq 'Boolean') {
      $keepFilePath = ($_.path | Select-Object -First 1)
    }
    foreach ($file in $_) {
      $file | Write-Debug
      if ($file.path -ne $keepFilePath) {
        (@(
          (Get-Date).ToString('yyyy-MM-dd hh:mm:ss'),
          $file.path,
          $keepFilePath,
          $file.hash
         ) -join "`t") |
          Tee-Object -Append -FilePath $logFile
        $destination = $duplicatesFolder + '\' + ($file.path -replace ':', '\\' -replace '\\[^\\]+$', '')
        if (-not (Test-Path $destination)) {
          $null = New-Item -Verbose -Force -ItemType Directory -Path $destination
        }
        Move-Item -Verbose -Force -Path $file.path -Destination $destination
        $null = New-Item -Verbose -ItemType SymbolicLink -Path $file.path -Value $keepFilePath
        $volumeMoved += $file.size
      }
    }
  }

"$($volumeMoved/(1 -shl 30)) GiB moved to '$duplicatesFolder'." | Write-Host
Stop-Transcript
