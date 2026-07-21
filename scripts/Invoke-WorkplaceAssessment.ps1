<# RayStudio Workplace Assessment - DE-CH HTML report #>
[CmdletBinding()]
param([switch]$NoOpen,[ValidateSet('DE-CH','EN')][string]$Lang='DE-CH')
$ErrorActionPreference='Continue'
$Started=Get-Date
$IsCompiled=[System.Diagnostics.Process]::GetCurrentProcess().ProcessName -notmatch '^(powershell|pwsh)$'
if($IsCompiled){
 $ExeDir=Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
 $OutDir=Join-Path $ExeDir 'output'
}else{
 $OutDir=Join-Path (Split-Path -Parent $PSScriptRoot) 'output'
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$Computer=$env:COMPUTERNAME
$Stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$JsonPath=Join-Path $OutDir "Assessment_${Computer}_${Stamp}.json"
$HtmlPath=Join-Path $OutDir "Assessment_${Computer}_${Stamp}.html"
$Utf8NoBom=[System.Text.UTF8Encoding]::new($false)
function IsAdmin{try{return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)}catch{return $false}}
function Finding($cat,$check,$status,$score,$max,$eKey,$eArgs,$risk,$rec,$details=@(),$item=$null){
 [pscustomobject]@{categoryKey=$cat;checkKey=$check;statusKey=$status;score=$score;maxScore=$max;scored=($max -gt 0);evidenceKey=$eKey;evidenceArgs=$eArgs;riskKey=$risk;recommendationKey=$rec;details=$details;itemKey=$item}
}
function Get-M365JoinInfo{
 $azureAdJoined=$false;$domainJoined=$false
 try{$out=& dsregcmd /status 2>$null;if($out){$azureAdJoined=($out -match 'AzureAdJoined\s*:\s*YES').Count -gt 0;$domainJoined=($out -match 'DomainJoined\s*:\s*YES').Count -gt 0}}catch{}
 $mdm=$false;try{$mdm=[bool](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Enrollments\*' -ErrorAction Stop)}catch{}
 $managed=[bool]($azureAdJoined -and $mdm)
 $suggestedMode=if($managed -or $domainJoined){'company'}else{'private'}
 [pscustomobject]@{AzureAdJoined=$azureAdJoined;DomainJoined=$domainJoined;Mdm=$mdm;SuggestedDeviceMode=$suggestedMode}
}

# --- Bestehende Checks (unveraendert) ---
function PendingFinding{
 $wu=Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
 $cbs=Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
 $pfr=@();try{$raw=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction Stop).PendingFileRenameOperations;if($raw){$pfr=@($raw|?{$_ -and $_.ToString().Trim() -ne ''})}}catch{}
 $tempOnly=$false;$hasApp=$false;$hasSystem=$false;$app=@();$sys=@();$tmp=@();$other=@()
 if($pfr.Count -gt 0){$tempOnly=$true;foreach($i in $pfr){$s=[string]$i;if($s -match '(?i)\\Windows\\Temp\\DEL[0-9A-F]+\.tmp$'){$tmp+=$s}else{$tempOnly=$false};if($s -match '(?i)\\Windows\\System32\\drivers\\|\\DriverStore\\|\\System32\\.*\.sys$'){$hasSystem=$true;$sys+=$s}elseif($s -match '(?i)OneDrive|Teams|MSEdge|Microsoft Edge|Chrome|Firefox|GamingServices|gamingservices|Office|ClickToRun|Adobe|Zoom|Webex'){$hasApp=$true;$app+=$s}elseif($s -notmatch '(?i)\\Windows\\Temp\\DEL[0-9A-F]+\.tmp$'){$other+=$s}}}
 $st='ok';$sc=15;$e='pendingNone';$r='riskNone';$rec='recNone';$class='none'
 if($wu -or $cbs){$st='critical';$sc=0;$e='pendingWindows';$r='riskWindowsPending';$rec='recRestartNow';$class='windows'}elseif($hasSystem){$st='warning';$sc=5;$e='pendingSystem';$r='riskSystemPending';$rec='recRestartSoon';$class='system'}elseif($hasApp){$st='warning';$sc=10;$e='pendingApp';$r='riskAppPending';$rec='recRestartConvenient';$class='app'}elseif($pfr.Count -gt 0 -and $tempOnly){$st='info';$sc=15;$e='pendingTemp';$r='riskTempOnly';$rec='recNoImmediateAction';$class='temp'}elseif($pfr.Count -gt 0){$st='warning';$sc=10;$e='pendingGeneric';$r='riskGenericPending';$rec='recReviewRestart';$class='generic'}
 $d=@("classification=$class","WU=$wu","CBS=$cbs","PendingRename=$($pfr.Count -gt 0)","PendingRenameCount=$($pfr.Count)");if($app){$d+='';$d+='Application files:';$d+=$app};if($sys){$d+='';$d+='System/driver files:';$d+=$sys};if($tmp){$d+='';$d+='Temporary cleanup files:';$d+=$tmp};if($other){$d+='';$d+='Other entries:';$d+=$other}
 Finding 'health' 'rebootStatus' $st $sc 15 $e @{count=$pfr.Count;wu=$wu;cbs=$cbs} $r $rec $d
}
function UptimeFinding{try{$os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop;$last=$os.LastBootUpTime;$days=[math]::Round(((Get-Date)-$last).TotalDays,1);$st='ok';$sc=10;$r='riskUptimeOk';$rec='recNone';if($days -gt 30){$st='warning';$sc=5;$r='riskLongUptime';$rec='recRegularRestart'};Finding 'health' 'uptime' $st $sc 10 'uptimeEvidence' @{days=$days;lastBoot=$last.ToString('dd.MM.yyyy HH:mm:ss')} $r $rec}catch{Finding 'health' 'uptime' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually'}}
function StorageFinding{try{$c=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop}catch{$c=$null};if(-not $c -or -not $c.Size){return Finding 'storage' 'systemDrive' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually'};$pct=[math]::Round(($c.FreeSpace/$c.Size)*100,1);$free=[math]::Round($c.FreeSpace/1GB,1);$size=[math]::Round($c.Size/1GB,1);$st='ok';$sc=15;$r='riskStorageOk';$rec='recNone';if($pct -lt 10){$st='critical';$sc=3;$r='riskStorageCritical';$rec='recFreeSpace'}elseif($pct -lt 20){$st='warning';$sc=10;$r='riskStorageWarning';$rec='recStorageCleanup'};Finding 'storage' 'systemDrive' $st $sc 15 'storageEvidence' @{freeGb=$free;sizeGb=$size;freePct=$pct} $r $rec}
function AdminFinding{$m=@();try{$m=@(Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop|select -ExpandProperty Name)}catch{$m=@('Query failed')};$cnt=@($m|?{$_ -ne 'Query failed'}).Count;$st='ok';$sc=10;$r='riskLocalAdminsOk';$rec='recNone';if($cnt -gt 6){$st='warning';$sc=4;$r='riskManyLocalAdmins';$rec='recLocalAdminsReduce'}elseif($cnt -gt 3){$st='warning';$sc=7;$r='riskSomeLocalAdmins';$rec='recLocalAdminsReview'};Finding 'management' 'localAdmins' $st $sc 10 'localAdminsEvidence' @{count=$cnt} $r $rec $m}
function RemoteFinding{
 $pat=@('TeamViewer','AnyDesk','RealVNC','VNC','UltraVNC','RustDesk','Splashtop','ScreenConnect','ConnectWise','LogMeIn')
 $hits=@();foreach($root in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')){try{Get-ItemProperty $root -ErrorAction SilentlyContinue|%{$dn=$_.DisplayName;if($dn){foreach($p in $pat){if($dn -match [regex]::Escape($p)){$hits+=$dn}}}}}catch{}}
 $hits=@($hits|sort -Unique)
 if($hits.Count -eq 0){Finding 'management' 'remoteTools' 'ok' 10 10 'remoteToolsNone' @{} 'riskRemoteToolsOk' 'recNone'}
 else{foreach($h in $hits){Finding 'management' 'remoteTools' 'warning' 4 10 'remoteToolFound' @{name=$h} 'riskRemoteTools' 'recRemoteTools' @($h) $h}}
}
function StartupFinding{
 $knownGoodPattern='(?i)BingWallpaper|Microsoft\\Edge\\Update|OneDriveSetup'
 $sus=@()
 foreach($rk in @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\Run')){try{$p=Get-ItemProperty $rk -ErrorAction SilentlyContinue;if($p){$p.PSObject.Properties|?{$_.Name -notmatch '^PS'}|%{if($_.Name -match $knownGoodPattern){return};$v=[string]$_.Value;if($v -match $knownGoodPattern){return};if($v -match '(?i)AppData\\Local\\Temp|\\Temp\\|powershell.+-enc|wscript|cscript|rundll32.+AppData'){$sus+=[pscustomobject]@{Name=$_.Name;Value=$v}}}}}catch{}}
 if($sus.Count -eq 0){Finding 'security' 'startupCheck' 'ok' 10 10 'startupEvidenceNone' @{} 'riskStartupOk' 'recNone'}
 else{foreach($s in $sus){Finding 'security' 'startupCheck' 'warning' 6 10 'startupEvidenceItem' @{name=$s.Name;value=$s.Value} 'riskStartupSuspicious' 'recStartupReview' @("$($s.Name)=$($s.Value)") $s.Name}}
}
function WindowsEditionFinding{try{$os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop;$sku=$os.OperatingSystemSKU;$cap=$os.Caption}catch{return Finding 'management' 'windowsEdition' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually'};$bizSkus=@(4,27,48,121,125,161,162);$isBiz=$bizSkus -contains $sku;if(-not $isBiz){return Finding 'management' 'windowsEdition' 'critical' 0 10 'editionHome' @{caption=$cap;sku=$sku} 'riskEditionHome' 'recEditionUpgrade' @("Caption=$cap","SKU=$sku")};$lic=$null;try{$lic=@(Get-CimInstance -Query "SELECT * FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" -ErrorAction Stop|?{$_.PartialProductKey})}catch{};if(-not $lic -or $lic.Count -eq 0){return Finding 'management' 'windowsEdition' 'info' 0 0 'queryUnavailable' @{caption=$cap} 'notScored' 'checkManually' @("Caption=$cap","SKU=$sku","LicenseQuery=empty_or_failed")};$best=$lic|?{$_.LicenseStatus -eq 1}|select -First 1;if(-not $best){$best=$lic|select -First 1};$ls=[int]$best.LicenseStatus;$lsMap=@{0='Unlicensed';1='Licensed';2='OOBGrace';3='OOTGrace';4='NonGenuineGrace';5='Notification';6='ExtendedGrace'};$lsText=$lsMap[$ls];$d=@("Caption=$cap","SKU=$sku","LicenseStatus=$ls ($lsText)","PartialProductKey=...$($best.PartialProductKey)","Name=$($best.Name)");if($ls -eq 1){Finding 'management' 'windowsEdition' 'ok' 10 10 'editionOkLicensed' @{caption=$cap;licenseStatus=$lsText} 'riskEditionOk' 'recNone' $d}elseif($ls -eq 0){Finding 'management' 'windowsEdition' 'critical' 0 10 'editionUnlicensed' @{caption=$cap;licenseStatus=$lsText} 'riskEditionUnlicensed' 'recLicenseActivate' $d}else{Finding 'management' 'windowsEdition' 'warning' 6 10 'editionOkGrace' @{caption=$cap;licenseStatus=$lsText} 'riskEditionGrace' 'recLicenseActivate' $d}}

# --- Windows-11-Bereitschaft (secureBoot/tpm hierher verschoben, plus neu: CPU/RAM/Storage) ---
function SecureBootFinding{
 try{$sb=Confirm-SecureBootUEFI -ErrorAction Stop;if($sb){return Finding 'windows11' 'secureBoot' 'ok' 10 10 'secureBootOn' @{} 'riskSecureBootOk' 'recNone'}else{return Finding 'windows11' 'secureBoot' 'warning' 5 10 'secureBootOff' @{} 'riskSecureBootOff' 'recSecureBoot'}}catch{
  $msg=[string]$_.Exception.Message
  if($msg -match '(?i)not supported|nicht unterst|non-UEFI'){return Finding 'windows11' 'secureBoot' 'critical' 0 10 'secureBootLegacyBios' @{} 'riskSecureBootLegacyBios' 'recSecureBootLegacyBios'}
 }
 # Fallback ohne Admin-Rechte: Registry-Wert ist im Gegensatz zu Confirm-SecureBootUEFI auch ohne Elevation lesbar
 try{$v=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' -Name UEFISecureBootEnabled -ErrorAction Stop).UEFISecureBootEnabled
  if($v -eq 1){return Finding 'windows11' 'secureBoot' 'ok' 10 10 'secureBootOn' @{} 'riskSecureBootOk' 'recNone' @('Quelle=Registry (UEFISecureBootEnabled)')}
  else{return Finding 'windows11' 'secureBoot' 'warning' 5 10 'secureBootOff' @{} 'riskSecureBootOff' 'recSecureBoot' @('Quelle=Registry (UEFISecureBootEnabled)')}
 }catch{}
 if(-not (IsAdmin)){Finding 'windows11' 'secureBoot' 'info' 0 0 'queryNeedsAdmin' @{} 'notScored' 'recRunAsAdminGeneric' @('Manuelle Pruefung als Administrator: Confirm-SecureBootUEFI')}
 else{Finding 'windows11' 'secureBoot' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually'}
}
function TpmFinding{
 try{$t=Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction Stop}catch{
  if(-not (IsAdmin)){return Finding 'windows11' 'tpm' 'info' 0 0 'queryNeedsAdmin' @{} 'notScored' 'recRunAsAdminGeneric' @('Manuelle Pruefung als Administrator: Get-Tpm')}
  return Finding 'windows11' 'tpm' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually'
 }
 if(-not $t){return Finding 'windows11' 'tpm' 'critical' 0 10 'tpmMissing' @{} 'riskTpmMissing' 'recTpmMissing'}
 $spec=[string]$t.SpecVersion;$maj=($spec -split ',')[0].Trim();$en=[bool]$t.IsEnabled_InitialValue;$ac=[bool]$t.IsActivated_InitialValue
 $d=@("SpecVersion=$spec","Manufacturer=$($t.ManufacturerIdTxt)","ManufacturerVersion=$($t.ManufacturerVersion)","Enabled=$en","Activated=$ac","Owned=$($t.IsOwned_InitialValue)")
 if($maj -notlike '2.*'){Finding 'windows11' 'tpm' 'critical' 0 10 'tpmOld' @{specVersion=$maj} 'riskTpmOld' 'recTpmUpgrade' $d}
 elseif(-not($en -and $ac)){Finding 'windows11' 'tpm' 'warning' 5 10 'tpmDisabled' @{specVersion=$maj;enabled=$en;activated=$ac} 'riskTpmDisabled' 'recTpmEnable' $d}
 else{Finding 'windows11' 'tpm' 'ok' 10 10 'tpmOk' @{specVersion=$maj} 'riskTpmOk' 'recNone' $d}
}
function CpuReadinessFinding{
 try{$cpu=Get-CimInstance Win32_Processor -ErrorAction Stop|select -First 1}catch{return Finding 'windows11' 'cpuReadiness' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually'}
 $name=[string]$cpu.Name
 $isArm=$name -match '(?i)snapdragon|qualcomm|ARMv'
 $intelGen=$null;$amdOk=$false
 if($name -match '(?i)Intel.*Core.*i[3579]-(\d)\d{3,4}[A-Z]{0,2}\d?\b'){$leadDigit=[int]$Matches[1];$intelGen=if($leadDigit -eq 1){13}else{$leadDigit}}
 if($name -match '(?i)Ryzen\s+[3579]\s+([2-9])\d{3}'){$amdOk=[int]$Matches[1] -ge 2}
 $d=@("CpuName=$name")
 if($isArm){Finding 'windows11' 'cpuReadiness' 'ok' 10 10 'cpuArm' @{name=$name} 'riskCpuOk' 'recNone' $d}
 elseif($intelGen -ne $null){if($intelGen -ge 8){Finding 'windows11' 'cpuReadiness' 'ok' 10 10 'cpuCompatible' @{name=$name} 'riskCpuOk' 'recNone' $d}else{Finding 'windows11' 'cpuReadiness' 'warning' 3 10 'cpuLikelyIncompatible' @{name=$name} 'riskCpuIncompatible' 'recCpuCheck' $d}}
 elseif($amdOk){Finding 'windows11' 'cpuReadiness' 'ok' 10 10 'cpuCompatible' @{name=$name} 'riskCpuOk' 'recNone' $d}
 else{Finding 'windows11' 'cpuReadiness' 'info' 0 0 'cpuUnknown' @{name=$name} 'notScored' 'recCpuCheck' $d}
}
function RamStorageMinFinding{
 try{$cs=Get-CimInstance Win32_ComputerSystem -ErrorAction Stop;$ramGb=[math]::Round($cs.TotalPhysicalMemory/1GB,1)}catch{return Finding 'windows11' 'ramStorageMin' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually'}
 $sizeGb=$null;try{$c=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop;$sizeGb=[math]::Round($c.Size/1GB,1)}catch{}
 $d=@("RamGb=$ramGb","SystemDriveSizeGb=$sizeGb")
 $ramOk=$ramGb -ge 4
 $storageOk=(-not $sizeGb) -or ($sizeGb -ge 64)
 if($ramOk -and $storageOk){Finding 'windows11' 'ramStorageMin' 'ok' 10 10 'ramStorageOk' @{ram=$ramGb;size=$sizeGb} 'riskRamStorageOk' 'recNone' $d}
 elseif(-not $ramOk){Finding 'windows11' 'ramStorageMin' 'critical' 0 10 'ramTooLow' @{ram=$ramGb} 'riskRamTooLow' 'recRamUpgrade' $d}
 else{Finding 'windows11' 'ramStorageMin' 'critical' 0 10 'storageTooSmall' @{size=$sizeGb} 'riskStorageTooSmall' 'recStorageUpgrade' $d}
}

# --- Security (neu) ---
function BitLockerFinding{
 try{$v=Get-BitLockerVolume -MountPoint 'C:' -ErrorAction Stop
  $status=[string]$v.ProtectionStatus;$method=[string]$v.EncryptionMethod
  $d=@("ProtectionStatus=$status","EncryptionMethod=$method","VolumeStatus=$($v.VolumeStatus)")
  if($status -eq 'On'){return Finding 'security' 'bitLocker' 'ok' 10 10 'bitLockerOn' @{method=$method} 'riskBitLockerOk' 'recNone' $d}
  else{return Finding 'security' 'bitLocker' 'critical' 0 10 'bitLockerOff' @{} 'riskBitLockerOff' 'recBitLockerEnable' $d}
 }catch{}
 try{
  $bde=& manage-bde -status C: 2>$null
  # manage-bde schreibt Fehlermeldungen (z.B. Zugriff verweigert) ebenfalls auf stdout - erst die erwarteten Statuszeilen
  # validieren, sonst wuerde ein Admin-Rechte-Fehler faelschlich als "BitLocker aus" interpretiert
  $protLine=$bde|?{$_ -match 'Protection Status'}|select -First 1
  if($protLine){
   $methodLine=$bde|?{$_ -match 'Encryption Method'}|select -First 1
   $on=$protLine -match 'Protection On'
   $d=@("manage-bde:ProtectionStatus=$($protLine.Trim())","manage-bde:EncryptionMethod=$($methodLine.Trim())")
   if($on){return Finding 'security' 'bitLocker' 'ok' 10 10 'bitLockerOn' @{method=[string]$methodLine} 'riskBitLockerOk' 'recNone' $d}
   else{return Finding 'security' 'bitLocker' 'critical' 0 10 'bitLockerOff' @{} 'riskBitLockerOff' 'recBitLockerEnable' $d}
  }
 }catch{}
 if(-not (IsAdmin)){Finding 'security' 'bitLocker' 'info' 0 0 'queryNeedsAdmin' @{} 'notScored' 'recRunAsAdminGeneric' @('Manuelle Pruefung als Administrator:','manage-bde -status C:','Get-BitLockerVolume -MountPoint C:')}
 else{Finding 'security' 'bitLocker' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually'}
}
function DefenderFinding{
 try{$m=Get-MpComputerStatus -ErrorAction Stop}catch{return Finding 'security' 'defenderStatus' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually'}
 $av=[bool]$m.AntivirusEnabled;$rt=[bool]$m.RealTimeProtectionEnabled;$age=$null;try{$age=[int]$m.AntivirusSignatureAge}catch{}
 $d=@("AntivirusEnabled=$av","RealTimeProtectionEnabled=$rt","AntivirusSignatureAge=$age Tage")
 if(-not $av){Finding 'security' 'defenderStatus' 'critical' 0 10 'defenderOff' @{} 'riskDefenderOff' 'recDefenderEnable' $d}
 elseif(-not $rt){Finding 'security' 'defenderStatus' 'critical' 3 10 'defenderRtOff' @{} 'riskDefenderRtOff' 'recDefenderRtEnable' $d}
 elseif($age -ne $null -and $age -gt 7){Finding 'security' 'defenderStatus' 'warning' 6 10 'defenderSignatureOld' @{age=$age} 'riskDefenderSignatureOld' 'recDefenderUpdate' $d}
 else{Finding 'security' 'defenderStatus' 'ok' 10 10 'defenderOk' @{} 'riskDefenderOk' 'recNone' $d}
}
function FirewallFinding{
 try{$p=Get-NetFirewallProfile -ErrorAction Stop}catch{return Finding 'security' 'firewallStatus' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually'}
 $off=@($p|?{-not $_.Enabled}|select -ExpandProperty Name)
 $d=@($p|%{"$($_.Name)=$($_.Enabled)"})
 if($off.Count -eq 0){Finding 'security' 'firewallStatus' 'ok' 10 10 'firewallAllOn' @{} 'riskFirewallOk' 'recNone' $d}
 elseif($off -contains 'Public'){Finding 'security' 'firewallStatus' 'critical' 0 10 'firewallPublicOff' @{list=($off -join ', ')} 'riskFirewallPublicOff' 'recFirewallEnable' $d}
 else{Finding 'security' 'firewallStatus' 'warning' 5 10 'firewallSomeOff' @{list=($off -join ', ')} 'riskFirewallSomeOff' 'recFirewallEnable' $d}
}
function WindowsUpdateFinding{
 $manualCmds=@('','Manuelle Pruefung bei Bedarf:','Get-Service wuauserv','Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10')
 $svcState=$null;$svcStart=$null;try{$svc=Get-Service -Name wuauserv -ErrorAction Stop;$svcState=[string]$svc.Status;$svcStart=[string]$svc.StartType}catch{}
 if($svcStart -eq 'Disabled'){$d=@("ServiceStatus=$svcState","ServiceStartType=$svcStart")+$manualCmds;return Finding 'security' 'updateCompliance' 'critical' 0 10 'updateServiceDisabled' @{} 'riskUpdateServiceDisabled' 'recUpdateServiceEnable' $d}
 $dt=$null;$src=$null
 try{$last=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Install' -Name LastSuccessTime -ErrorAction Stop).LastSuccessTime;if($last){$dt=[datetime]$last;$src='Registry (WindowsUpdate\Auto Update)'}}catch{}
 if(-not $dt){try{$hf=Get-HotFix -ErrorAction Stop|?{$_.InstalledOn}|Sort-Object InstalledOn -Descending|select -First 1;if($hf){$dt=$hf.InstalledOn;$src="Get-HotFix ($($hf.HotFixID))"}}catch{}}
 if(-not $dt){$d=@("ServiceStatus=$svcState","ServiceStartType=$svcStart")+$manualCmds;return Finding 'security' 'updateCompliance' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually' $d}
 $days=[math]::Round(((Get-Date)-$dt).TotalDays,0)
 $d=@("Quelle=$src","LetzterZeitpunkt=$($dt.ToString('dd.MM.yyyy HH:mm'))","TageSeither=$days","ServiceStatus=$svcState","ServiceStartType=$svcStart")+$manualCmds
 if($days -le 30){Finding 'security' 'updateCompliance' 'ok' 10 10 'updateRecent' @{days=$days} 'riskUpdateOk' 'recNone' $d}
 elseif($days -le 60){Finding 'security' 'updateCompliance' 'warning' 5 10 'updateAging' @{days=$days} 'riskUpdateAging' 'recUpdateCheck' $d}
 else{Finding 'security' 'updateCompliance' 'critical' 0 10 'updateStale' @{days=$days} 'riskUpdateStale' 'recUpdateCheck' $d}
}
function RdpFinding{
 $deny=$null;try{$deny=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction Stop).fDenyTSConnections}catch{}
 if($deny -eq $null){return Finding 'security' 'rdpExposure' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually'}
 if($deny -eq 1){return Finding 'security' 'rdpExposure' 'ok' 10 10 'rdpDisabled' @{} 'riskRdpOk' 'recNone' @("fDenyTSConnections=1")}
 $nla=$null;try{$nla=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -ErrorAction Stop).UserAuthentication}catch{}
 $d=@("fDenyTSConnections=0","UserAuthentication(NLA)=$nla")
 if($nla -eq 1){Finding 'security' 'rdpExposure' 'warning' 6 10 'rdpEnabledNla' @{} 'riskRdpEnabledNla' 'recRdpReview' $d}
 else{Finding 'security' 'rdpExposure' 'critical' 0 10 'rdpEnabledNoNla' @{} 'riskRdpEnabledNoNla' 'recRdpNla' $d}
}
function VbsFinding($join){
 try{$dg=Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop}catch{return Finding 'security' 'credentialGuard' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually'}
 $running=@($dg.SecurityServicesRunning);$vbs=[int]$dg.VirtualizationBasedSecurityStatus
 $managed=[bool]($join.AzureAdJoined -and $join.Mdm)
 $manualCmds=@('','Manuelle Tiefenpruefung bei Bedarf (erhoehte PowerShell/CMD):','gpresult /r','gpresult /scope user /r','gpresult /v','systeminfo | findstr /i "Virtualization"')
 $d=@("VirtualizationBasedSecurityStatus=$vbs","SecurityServicesConfigured=$($dg.SecurityServicesConfigured -join ',')","SecurityServicesRunning=$($running -join ',')","GeraetVerwaltet(Entra+Intune)=$managed")+$manualCmds
 # Bewertung erfolgt immer; ob dieser Check bei privaten Geraeten in die Gesamtwertung einfliesst, entscheidet der Privat/Firmengeraet-Umschalter im Report (Client-seitig)
 if($running -contains 1){Finding 'security' 'credentialGuard' 'ok' 10 10 'credGuardOn' @{} 'riskCredGuardOk' 'recNone' $d}
 elseif($vbs -ge 1){Finding 'security' 'credentialGuard' 'warning' 5 10 'credGuardAvailable' @{} 'riskCredGuardAvailable' 'recCredGuardEnable' $d}
 else{Finding 'security' 'credentialGuard' 'info' 0 0 'credGuardUnsupported' @{} 'notScored' 'checkManually' $d}
}

# --- Management (neu) ---
function LapsFinding{
 $hits=@()
 foreach($root in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')){try{Get-ItemProperty $root -ErrorAction SilentlyContinue|%{$dn=$_.DisplayName;if($dn -match '(?i)Local Administrator Password Solution|LAPS'){$hits+=$dn}}}catch{}}
 $winLapsPolicy=Test-Path 'HKLM:\SOFTWARE\Microsoft\Policies\LAPS'
 $d=@("UninstallHits=$($hits -join '; ')","WindowsLAPSPolicy=$winLapsPolicy")
 if($hits.Count -gt 0 -or $winLapsPolicy){Finding 'management' 'lapsStatus' 'ok' 10 10 'lapsDetected' @{} 'riskLapsOk' 'recNone' $d}
 else{Finding 'management' 'lapsStatus' 'warning' 4 10 'lapsNotDetected' @{} 'riskLapsMissing' 'recLapsDeploy' $d}
}

# --- M365 / Entra: rein informativ, zaehlt nicht in die Gesamtwertung (maxScore=0) ---
function M365Finding($join){
 $joinLabel=if($join.AzureAdJoined -and $join.DomainJoined){'Hybrid Azure AD / Entra + On-Premises'}elseif($join.AzureAdJoined){'Microsoft Entra ID (Azure AD) Joined'}elseif($join.DomainJoined){'On-Premises Active Directory Joined'}else{'Nicht verbunden / nicht ermittelbar'}
 $managed=$join.AzureAdJoined -and $join.Mdm
 $d=@("AzureAdJoined=$($join.AzureAdJoined)","DomainJoined=$($join.DomainJoined)","MDMEnrollmentKeysFound=$($join.Mdm)","VorgeschlagenerGeraetemodus=$($join.SuggestedDeviceMode)")
 if($managed){Finding 'm365' 'm365Status' 'ok' 0 0 'm365JoinStatusManaged' @{join=$joinLabel} 'riskM365Managed' 'recNone' $d}
 else{Finding 'm365' 'm365Status' 'info' 0 0 'm365JoinStatus' @{join=$joinLabel} 'notScored' 'recNone' $d}
}

# --- Defender-Ausschluesse: Malware traegt sich hier gerne ein, um sich vor Scans zu verstecken ---
function DefenderExclusionsFinding{
 $manualCmds=@('','Manuelle Pruefung als Administrator:','Get-MpPreference | Select-Object -ExpandProperty ExclusionPath','Get-MpPreference | Select-Object -ExpandProperty ExclusionExtension','Get-MpPreference | Select-Object -ExpandProperty ExclusionProcess')
 try{$p=Get-MpPreference -ErrorAction Stop}catch{return Finding 'security' 'defenderExclusions' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually' $manualCmds}
 $needsAdmin={param($v)$v -match '(?i)Must be an administrator'}
 $rawAll=@($p.ExclusionPath)+@($p.ExclusionExtension)+@($p.ExclusionProcess)+@($p.ExclusionIpAddress)|?{$_}
 if($rawAll.Count -gt 0 -and ($rawAll|?{& $needsAdmin $_}).Count -eq $rawAll.Count){return Finding 'security' 'defenderExclusions' 'info' 0 0 'exclusionsNeedsAdmin' @{} 'notScored' 'recExclusionsRunAsAdmin' $manualCmds}
 $items=@()
 foreach($v in @($p.ExclusionPath|?{$_ -and -not (& $needsAdmin $_)})){$items+=[pscustomobject]@{Type='Pfad';Value=$v}}
 foreach($v in @($p.ExclusionExtension|?{$_ -and -not (& $needsAdmin $_)})){$items+=[pscustomobject]@{Type='Datei-Endung';Value=$v}}
 foreach($v in @($p.ExclusionProcess|?{$_ -and -not (& $needsAdmin $_)})){$items+=[pscustomobject]@{Type='Prozess';Value=$v}}
 foreach($v in @($p.ExclusionIpAddress|?{$_ -and -not (& $needsAdmin $_)})){$items+=[pscustomobject]@{Type='IP-Adresse';Value=$v}}
 if($items.Count -eq 0){Finding 'security' 'defenderExclusions' 'ok' 10 10 'exclusionsNone' @{} 'riskExclusionsOk' 'recNone'}
 else{foreach($it in $items){Finding 'security' 'defenderExclusions' 'warning' 5 10 'exclusionsItem' @{type=$it.Type;value=$it.Value} 'riskExclusionsFound' 'recExclusionsReview' @("Typ=$($it.Type)","Wert=$($it.Value)") "$($it.Type)|$($it.Value)"}}
}

# --- Windows-Versionsaktualitaet: Vergleich gegen die zum Skriptstand bekannte aktuelle Version ---
function WinVersionCurrencyFinding{
 try{$os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop;$rp=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop}catch{return Finding 'windows11' 'winVersionCurrency' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually'}
 $display=[string]$rp.DisplayVersion;$build=[string]$rp.CurrentBuild;$ubr=$rp.UBR
 $latest='25H2'
 $d=@("Caption=$($os.Caption)","DisplayVersion=$display","CurrentBuild=$build","UBR=$ubr","ZumSkriptstandBekannteAktuellsteVersion=$latest","Manuelle Tagesaktuelle Pruefung: https://learn.microsoft.com/windows/release-health/")
 if($os.Caption -match 'Windows 10'){return Finding 'windows11' 'winVersionCurrency' 'critical' 0 10 'versionWin10Eol' @{} 'riskVersionWin10Eol' 'recVersionUpgradeWin11' $d}
 # 'YYHn' -> fortlaufende Halbjahres-Sequenznummer, damit auch zukuenftige Versionen (z.B. 26H1) korrekt als "neuer" statt "unbekannt" erkannt werden
 function ToHalfYearSeq($v){if($v -match '^(\d{2})H([12])$'){[int]$Matches[1]*2+([int]$Matches[2]-1)}else{$null}}
 $curSeq=ToHalfYearSeq $display;$latestSeq=ToHalfYearSeq $latest
 if($curSeq -eq $null){Finding 'windows11' 'winVersionCurrency' 'info' 0 0 'versionUnknown' @{display=$display} 'notScored' 'recVersionCheckManual' $d}
 elseif($curSeq -ge $latestSeq){$eKey=if($curSeq -eq $latestSeq){'versionCurrent'}else{'versionAhead'};Finding 'windows11' 'winVersionCurrency' 'ok' 10 10 $eKey @{display=$display} 'riskVersionOk' 'recNone' $d}
 else{$gap=$latestSeq-$curSeq;if($gap -ge 4){Finding 'windows11' 'winVersionCurrency' 'critical' 0 10 'versionBehind' @{display=$display;latest=$latest} 'riskVersionBehind' 'recVersionUpdate' $d}else{Finding 'windows11' 'winVersionCurrency' 'warning' 5 10 'versionBehind' @{display=$display;latest=$latest} 'riskVersionBehind' 'recVersionUpdate' $d}}
}

function BatteryFinding{try{$b=@(Get-CimInstance Win32_Battery -ErrorAction Stop)}catch{return Finding 'health' 'batteryHealth' 'info' 0 0 'queryUnavailable' @{} 'notScored' 'checkManually'};if(-not $b -or $b.Count -eq 0){return Finding 'health' 'batteryHealth' 'info' 0 0 'batteryNotPresent' @{} 'notScored' 'recNone'};$bs=$b[0].BatteryStatus;$pct=$b[0].EstimatedChargeRemaining;$design=$null;$full=$null;try{$design=(Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryStaticData -ErrorAction Stop|select -First 1).DesignedCapacity;$full=(Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryFullChargedCapacity -ErrorAction Stop|select -First 1).FullChargedCapacity}catch{};$d=@("BatteryStatus=$bs","EstimatedChargeRemaining=$pct%","DesignedCapacity=$design","FullChargedCapacity=$full");if(-not $design -or -not $full -or $design -eq 0){return Finding 'health' 'batteryHealth' 'info' 0 0 'batteryWearUnavailable' @{chargePct=$pct} 'notScored' 'checkManually' $d};$wear=[math]::Round((1-($full/$design))*100,1);$st='ok';$sc=10;$e='batteryHealthy';$r='riskBatteryOk';$rec='recNone';if($wear -gt 40){$st='critical';$sc=0;$e='batteryWornCritical';$r='riskBatteryWornCritical';$rec='recBatteryReplace'}elseif($wear -gt 20){$st='warning';$sc=5;$e='batteryWornWarning';$r='riskBatteryWornWarning';$rec='recBatteryMonitor'};Finding 'health' 'batteryHealth' $st $sc 10 $e @{wearPct=$wear;chargePct=$pct} $r $rec $d}

$join=Get-M365JoinInfo
$findings=@()
$findings+=PendingFinding;$findings+=UptimeFinding;$findings+=BatteryFinding;$findings+=StorageFinding;$findings+=AdminFinding;$findings+=RemoteFinding;$findings+=StartupFinding
$findings+=SecureBootFinding;$findings+=TpmFinding;$findings+=CpuReadinessFinding;$findings+=RamStorageMinFinding;$findings+=WinVersionCurrencyFinding
$findings+=WindowsEditionFinding
$findings+=BitLockerFinding;$findings+=DefenderFinding;$findings+=DefenderExclusionsFinding;$findings+=FirewallFinding;$findings+=WindowsUpdateFinding;$findings+=RdpFinding;$findings+=(VbsFinding $join)
$findings+=LapsFinding
$findings+=(M365Finding $join)

# security, windows11, health, storage, management zaehlen in die Gesamtwertung; m365 (immer info) nicht.
$totalCategories=@('security','windows11','health','storage','management')
$scoredAll=@($findings|?{$_.maxScore -gt 0})
$categoryOrder=@('security','windows11','health','storage','management','m365')
$presentCats=@($scoredAll.categoryKey|select -Unique)
$orderedCats=@($categoryOrder|?{$presentCats -contains $_})+@($presentCats|?{$categoryOrder -notcontains $_})
$cats=[ordered]@{}
foreach($cat in $orderedCats){$f=@($scoredAll|?{$_.categoryKey -eq $cat});if($f.Count){$s=($f|measure score -Sum).Sum;$m=($f|measure maxScore -Sum).Sum;$cats[$cat]=[pscustomobject]@{score=$s;max=$m;percent=[math]::Round(($s/$m)*100);count=$f.Count;counted=($totalCategories -contains $cat)}}}
$totalScored=@($scoredAll|?{$totalCategories -contains $_.categoryKey})
$totalScore=($totalScored|measure score -Sum).Sum;$totalMax=($totalScored|measure maxScore -Sum).Sum
$overall=if($totalMax -gt 0){[math]::Round(($totalScore/$totalMax)*100)}else{0}
$payload=[pscustomobject]@{version='2.0';computer=$Computer;user=$env:USERNAME;admin=(IsAdmin);started=$Started.ToString('s');completed=(Get-Date).ToString('s');lang=$Lang;suggestedDeviceMode=$join.SuggestedDeviceMode;scoring=[pscustomobject]@{score=$totalScore;max=$totalMax;percent=$overall;categories=$cats};findings=$findings}
$json=$payload|ConvertTo-Json -Depth 12;[IO.File]::WriteAllText($JsonPath,$json,$Utf8NoBom);$b64=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
$html=@'
<!doctype html><html lang="de-CH"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>RayStudio Workplace Assessment</title><meta name="description" content="RayStudio Workplace Assessment - Offline Windows-Ger&auml;tezustands- und Sicherheitsbericht"><meta property="og:title" content="RayStudio Workplace Assessment"><style>
:root{--bg:#071120;--panel:#111c2e;--line:#26364f;--text:#eef5ff;--muted:#adc0dd;--blue:#2f6df6;--green:#55d66b;--yellow:#f6ad2f;--red:#ef5350;--info:#38bdf8;--orange:#ffb020}
*{box-sizing:border-box}
body{margin:0;background:#071120;color:var(--text);font-family:Segoe UI,Arial,sans-serif}
.wrap{max-width:1460px;margin:0 auto;padding:28px}
.top{display:flex;gap:18px;align-items:flex-start}
.brand{display:flex;align-items:center;gap:9px;font-size:12px;color:#77aaff;font-weight:800;letter-spacing:.8px;text-transform:uppercase}
.title{font-size:30px;font-weight:850;margin-top:4px}
.meta{font-size:13px;color:var(--muted);margin-top:4px}
.scoreBox{margin-left:auto;text-align:right;display:flex;align-items:center;gap:14px}
.score{font-size:58px;font-weight:900}
.overallLabel{font-size:15px;border:1px solid var(--line);border-radius:14px;padding:8px 12px;background:#0b1526;color:var(--muted);font-weight:800}
.btn{border:0;border-radius:10px;background:var(--blue);color:white;padding:10px 14px;font-size:13px;font-weight:800;cursor:pointer}
.btn.secondary{background:#23324a}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:14px;margin:24px 0}
.card{border:1px solid var(--line);border-radius:14px;background:var(--panel);padding:20px;min-height:122px}
.card.optional{opacity:.82;border-style:dashed}
.optionalTag{text-align:center;font-size:10px;color:var(--muted);margin-top:6px;text-transform:uppercase;letter-spacing:.4px}
.donut{width:86px;height:86px;border-radius:50%;display:grid;place-items:center;margin:0 auto 12px}
.donutInner{width:58px;height:58px;border-radius:50%;background:#0d1728;display:grid;place-items:center;font-weight:900;font-size:18px}
.card h3{text-align:center;margin:5px 0;font-size:15px}
.section{border:1px solid var(--line);border-radius:16px;background:var(--panel);padding:20px;margin-top:20px}
.hint{font-size:13px;color:var(--muted);margin-bottom:14px}
.tabs{display:flex;gap:8px;flex-wrap:wrap;margin:10px 0 14px}
.tab{border:1px solid var(--line);background:#142036;color:var(--text);border-radius:9px;padding:9px 13px;font-weight:800;cursor:pointer}
.tab.active{background:#dcecff;color:#071120}
.tools{display:flex;gap:10px;margin-bottom:12px}
.search{flex:1;border:1px solid var(--line);border-radius:10px;background:#0a1424;color:var(--text);padding:12px}
table{width:100%;border-collapse:collapse;font-size:13px}
th,td{padding:11px 10px;border-bottom:1px solid #24344d;text-align:left;vertical-align:top}
th{color:#dcecff;background:#0b1526;position:sticky;top:0}
.row{cursor:pointer}
.row:hover{background:#17243a}
.row.selected{background:#2563eb!important;color:#fff}
.row.selected td{color:#fff}
.badge{display:inline-block;border-radius:999px;padding:5px 10px;font-size:12px;font-weight:900;color:#071120}
.ok{background:var(--green)}
.warning{background:var(--yellow)}
.critical{background:var(--red);color:#fff}
.info{background:var(--info)}
.details{display:none;background:#0a1424}
.details.open{display:table-row}
.pre{white-space:pre-wrap;font-family:Consolas,monospace;color:#dcecff}
.summary{border-left:4px solid var(--orange);padding:8px 0 8px 14px;margin:8px 0 14px;color:#dcecff}
.footer{margin-top:18px;color:var(--muted);font-size:12px;text-align:right}
.error{display:none;background:#451414;border:1px solid #8a2c2c;color:#ffdede;border-radius:12px;padding:14px;margin:14px 0}
.ackBadge{display:inline-block;border-radius:999px;padding:3px 9px;font-size:11px;font-weight:800;background:#23324a;color:#9fd3ff;margin-left:8px}
.scoreOrig{color:var(--muted);text-decoration:line-through;margin-right:6px}
.ackBox{border-top:1px dashed var(--line);margin-top:12px;padding-top:12px}
.ackRow{display:flex;align-items:center;gap:10px;flex-wrap:wrap}
.ackRow label{font-size:13px;color:var(--muted);display:flex;align-items:center;gap:6px;cursor:pointer}
.ackReason{flex:1;min-width:220px;border:1px solid var(--line);border-radius:8px;background:#0a1424;color:var(--text);padding:8px 10px;font-size:13px}
.ackMeta{font-size:11px;color:var(--muted)}
.adjustedNote{font-size:12px;color:#9fd3ff;margin-top:6px}
.modeSwitch{display:flex;gap:14px;align-items:center;margin-top:10px;padding:10px 14px;border:1px solid var(--line);border-radius:12px;background:#0b1526;width:fit-content}
.modeSwitch b{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.4px}
.modeSwitch label{display:flex;align-items:center;gap:6px;font-size:14px;font-weight:800;cursor:pointer}
@media(max-width:1100px){.cards{grid-template-columns:1fr 1fr}.top{flex-wrap:wrap}.scoreBox{margin-left:0}.tools{flex-wrap:wrap}.search{min-width:100%}}
@media print{.tabs,.tools,.btn{display:none}body{background:white;color:black}.section,.card{background:white;color:black;border-color:#aaa}.meta,.hint,.footer{color:#333}th,td{color:black;border-color:#ddd}.badge{color:black}.donutInner{background:white}}
</style></head><body><div class="wrap"><div class="top"><div><div class="brand">RAYSTUDIO WORKPLACE ASSESSMENT</div><div class="title" id="title"></div><div class="meta" id="meta"></div><div class="modeSwitch" id="modeSwitch"></div></div><div class="scoreBox"><div><div class="score" id="score">--%</div><div class="adjustedNote" id="adjustedNote" style="display:none"></div></div><div class="overallLabel" id="overallLabel"></div><button class="btn" onclick="window.print()" id="printBtn"></button></div></div><div id="err" class="error"></div><div class="cards" id="cards"></div><div class="section"><h2 id="sectionTitle"></h2><div class="hint" id="hint"></div><div class="tabs" id="tabs"></div><div class="tools"><input class="search" id="q" oninput="renderTable()"><button class="btn secondary" onclick="expandAll()" id="expandBtn"></button><button class="btn secondary" onclick="collapseAll()" id="collapseBtn"></button><button class="btn" onclick="downloadJson()" id="jsonBtn"></button></div><div style="overflow:auto;max-height:700px"><table><thead><tr><th id="thStatus"></th><th id="thCategory"></th><th id="thCheck"></th><th id="thScore"></th><th id="thEvidence"></th><th id="thRisk"></th><th id="thRecommendation"></th></tr></thead><tbody id="tbody"></tbody></table></div></div><div class="footer" id="footer"></div></div><script>
const DATA_B64='__DATA_B64__';let data=null,filter='all',ackState={},deviceMode='private';
const CATEGORY_ORDER=['security','windows11','health','storage','management','m365'];
const TOTAL_CATEGORIES=['security','windows11','health','storage','management'];
const T={
title:'Gerätezustands- und Sicherheitsbericht',print:'Drucken / als PDF speichern',admin:'Administrator',yes:'Ja',no:'Nein',language:'Sprache',overall:'Gesamtbewertung',score:'Bewertung',section:'Kritische Punkte & Empfehlungen',hint:'Findings werden nach Auswirkung priorisiert. Technische Details sind erst nach Klick auf eine Zeile sichtbar.',search:'Suchen nach Kategorie, Empfehlung oder Evidenz...',expand:'Alle Details',collapse:'Details schliessen',json:'JSON exportieren',technical:'Technische Details',noDetails:'Keine zusätzlichen technischen Details vorhanden.',renderError:'Fehler beim Laden des Reports: ',status:'Status',category:'Kategorie',check:'Prüfung',evidence:'Evidenz',risk:'Risiko',recommendation:'Empfehlung',all:'Alle',critical:'Kritisch',warning:'Warnung',info:'Hinweis',ok:'OK',notCounted:'Nicht in Gesamtwertung',
modeSwitchLabel:'Geräteklasse',modePrivate:'Privates Gerät',modeCompany:'Firmengerät',companyOnlyNote:'Nicht bewertet (privates Gerät)',
ackLabel:'Bewusst akzeptiert (Ausnahme dokumentiert)',ackReasonPlaceholder:'Begründung erfassen (wer/warum) - Pflicht für Audit-Nachweis...',ackSavedPrefix:'Akzeptiert am',ackReset:'Akzeptanz zurücksetzen',ackBadge:'Akzeptiert',adjustedScoreNote:'Bewertung berücksichtigt {n} bewusst akzeptierte Ausnahme(n). Ursprüngliche Bewertung: {orig}%.',ackNeedsReason:'Bitte Begründung erfassen, bevor die Akzeptanz gespeichert wird.',
security:'Sicherheit',health:'Gerätezustand',storage:'Speicher',management:'Verwaltung',windows11:'Windows 11 Bereitschaft',m365:'Microsoft 365 / Entra',
rebootStatus:'Neustartstatus',uptime:'Laufzeit / letzter Neustart',batteryHealth:'Akkuzustand',systemDrive:'Systemlaufwerk',localAdmins:'Lokale Administratoren',remoteTools:'Fernwartungstools',startupCheck:'Autostart-Prüfung',secureBoot:'Secure Boot',tpm:'TPM-Chip (Trusted Platform Module)',windowsEdition:'Windows-Edition und Lizenzstatus',
bitLocker:'BitLocker-Verschlüsselung',defenderStatus:'Windows Defender / Virenschutz',defenderExclusions:'Defender-Ausschlüsse',firewallStatus:'Windows-Firewall',updateCompliance:'Windows-Update-Status',rdpExposure:'Remotedesktop (RDP)',credentialGuard:'Credential Guard / VBS',lapsStatus:'Lokales Administrator-Passwort (LAPS)',cpuReadiness:'CPU-Kompatibilität',ramStorageMin:'Arbeitsspeicher & Speicherkapazität',winVersionCurrency:'Windows-Versionsaktualität',m365Status:'Geräteanbindung (Entra / Intune)',
pendingNone:'Kein Neustart ausstehend.',pendingWindows:'Windows benötigt einen Neustart, um Updates oder Komponentenwartung abzuschliessen.',pendingSystem:'System- oder Treiberdateien warten auf den nächsten Neustart.',pendingApp:'Eine Anwendung hat ausstehende Dateiänderungen, zum Beispiel OneDrive, Teams, Browser, Office oder Gaming Services.',pendingTemp:'Es sind nur temporäre DEL*.tmp-Bereinigungen ausstehend.',pendingGeneric:'Dateien sind für den nächsten Neustart zum Umbenennen oder Löschen vorgemerkt.',riskNone:'Es wurden keine ausstehenden Neustart-Signale erkannt.',riskWindowsPending:'Ausstehende Windows-Wartung kann weitere Updates blockieren und den Gerätezustand verschlechtern.',riskSystemPending:'Treiber- oder Systemänderungen sind noch nicht vollständig abgeschlossen.',riskAppPending:'Die Anwendung ist möglicherweise erst nach einem Neustart vollständig aktualisiert. Dies wird nicht als kritisches Windows-Problem bewertet.',riskTempOnly:'Reine temporäre Bereinigung, kein relevanter Gerätezustandsverlust.',riskGenericPending:'Einige Änderungen sind noch nicht vollständig abgeschlossen.',recNone:'Keine Aktion erforderlich.',recRestartNow:'Gerät neu starten und Assessment erneut ausführen.',recRestartSoon:'Gerät neu starten und Assessment erneut ausführen.',recRestartConvenient:'Neustart bei Gelegenheit einplanen. Keine kritische Einstufung, solange Windows Update und CBS nicht ausstehend sind.',recNoImmediateAction:'Keine Sofortmassnahme erforderlich.',recReviewRestart:'Einträge prüfen und Neustart bei Gelegenheit einplanen.',
uptimeEvidence:'Laufzeit: {days} Tage; letzter Neustart: {lastBoot}',riskUptimeOk:'Das Gerät wurde kürzlich neu gestartet.',riskLongUptime:'Lange Laufzeiten können Updates und Korrekturen verzögern.',recRegularRestart:'Regelmässige Neustarts einplanen.',
storageEvidence:'C: {freeGb} GB frei von {sizeGb} GB ({freePct}%)',riskStorageOk:'Ausreichend freier Speicherplatz vorhanden.',riskStorageCritical:'Zu wenig freier Speicher kann Updates und Anwendungen blockieren.',riskStorageWarning:'Der freie Speicherplatz wird knapp.',recFreeSpace:'Speicherplatz freigeben.',recStorageCleanup:'Speicherbereinigung prüfen.',
localAdminsEvidence:'{count} lokale Administratoren erkannt.',riskLocalAdminsOk:'Keine auffällige Anzahl lokaler Administratoren erkannt.',riskManyLocalAdmins:'Viele lokale Administratoren erhöhen das Risiko von Rechteausweitungen.',riskSomeLocalAdmins:'Mehr lokale Administratoren als üblich.',recLocalAdminsReduce:'Mitglieder prüfen, reduzieren und LAPS/Windows LAPS sicherstellen.',recLocalAdminsReview:'Mitglieder der lokalen Administratoren prüfen.',
remoteToolsNone:'Keine gängigen Fernwartungstools erkannt.',remoteToolFound:'{name}',riskRemoteToolsOk:'Keine Auffälligkeit erkannt.',riskRemoteTools:'Nicht dokumentiertes Fernwartungstool erhöht Support- und Sicherheitsrisiken.',recRemoteTools:'Tool prüfen, freigeben oder entfernen und dokumentieren. Falls bewusst im Einsatz: unten als akzeptiert markieren.',
startupEvidenceNone:'Keine auffälligen Autostart-Einträge erkannt.',startupEvidenceItem:'{name}={value}',riskStartupOk:'Keine auffälligen Autostart-Einträge erkannt.',riskStartupSuspicious:'Auffälliger Autostart-Eintrag kann auf unerwünschte Persistenz hinweisen.',recStartupReview:'Autostart-Eintrag prüfen. Falls bekannt/gewollt: unten als akzeptiert markieren.',
secureBootOn:'Secure Boot ist aktiviert.',secureBootOff:'Secure Boot ist nicht aktiviert.',secureBootLegacyBios:'Gerät bootet im Legacy-BIOS-Modus, Secure Boot ist nicht verfügbar.',riskSecureBootOk:'Keine Auffälligkeit erkannt.',riskSecureBootOff:'Ohne Secure Boot steigt das Risiko von Bootkit-Angriffen.',riskSecureBootLegacyBios:'Ohne UEFI/Secure Boot ist kein Schutz vor Bootkit-Angriffen möglich; auch TPM- und Windows-11-Kompatibilität sind eingeschränkt.',recSecureBoot:'Secure Boot im UEFI aktivieren, sofern unterstützt.',recSecureBootLegacyBios:'Umstellung von Legacy-BIOS auf UEFI pruefen (Datensicherung vorher zwingend), sofern Hardware dies unterstuetzt.',
queryUnavailable:'Abfrage nicht möglich.',queryNeedsAdmin:'Abfrage benötigt Administratorrechte.',notScored:'Nicht bewertet.',checkManually:'Manuell prüfen.',recRunAsAdminGeneric:'Assessment als Administrator ausführen, um diesen Wert zuverlässig zu ermitteln (siehe technische Details für den manuellen Befehl).',
tpmOk:'TPM 2.0 vorhanden, aktiviert und bereit (Spec-Version {specVersion}).',tpmDisabled:'TPM 2.0-Chip erkannt, ist jedoch nicht vollständig aktiviert (Enabled={enabled}, Activated={activated}).',tpmOld:'Es wurde nur TPM-Spezifikation {specVersion} erkannt. Windows 11 setzt TPM 2.0 voraus.',tpmMissing:'Kein TPM-Chip erkannt.',riskTpmOk:'Die Hardware-Sicherheitsvoraussetzung für BitLocker, Windows Hello und Windows 11 ist erfüllt.',riskTpmDisabled:'Ohne aktives TPM sind BitLocker-Verschlüsselung und Windows Hello eingeschränkt oder nicht verfügbar. Windows-11-Kompatibilität kann beeinträchtigt sein.',riskTpmOld:'TPM-Version unter 2.0 erfüllt die offizielle Windows-11-Mindestanforderung nicht.',riskTpmMissing:'Ohne TPM-Chip ist Windows 11 gemäss Microsoft-Anforderungen nicht offiziell unterstützt. BitLocker und Windows Hello sind stark eingeschränkt.',recTpmEnable:'TPM im UEFI/BIOS aktivieren (häufig unter Security als "Security Chip", "fTPM" oder "PTT").',recTpmUpgrade:'Hardware-Kompatibilität für TPM 2.0 prüfen bzw. Geräteersatz für Windows-11-Einsatz einplanen.',recTpmMissing:'Gerät auf TPM-2.0-Fähigkeit prüfen (physischer Chip oder fTPM/PTT im UEFI aktivierbar) oder Geräteersatz einplanen.',
editionOkLicensed:'{caption}, Lizenzstatus: {licenseStatus}.',editionOkGrace:'{caption}, Lizenzstatus: {licenseStatus} (befristete Gnadenfrist).',editionUnlicensed:'{caption}, Lizenzstatus: {licenseStatus}.',editionHome:'{caption} (SKU {sku}) ist keine Business-Edition.',riskEditionOk:'Die Windows-Edition unterstützt BitLocker, Gruppenrichtlinien, RDP-Host und Domain-Join, und die Lizenz ist korrekt aktiviert.',riskEditionGrace:'Die Lizenz befindet sich in einer befristeten Gnadenfrist und ist noch nicht dauerhaft aktiviert. Nach Ablauf drohen Funktionseinschränkungen.',riskEditionUnlicensed:'Windows ist nicht aktiviert. Dies ist ein Compliance-Risiko und kann zu Funktionseinschränkungen führen.',riskEditionHome:'Die Home-Edition unterstützt kein BitLocker, keine Gruppenrichtlinien, keinen RDP-Host und keinen Domain-Join. Für den Geschäftseinsatz ist dies nicht geeignet.',recLicenseActivate:'Windows-Aktivierung prüfen und Lizenz vollständig aktivieren (Einstellungen > Update und Sicherheit > Aktivierung).',recEditionUpgrade:'Edition-Upgrade auf Windows Pro, Enterprise oder Education prüfen, um Geschäftsfunktionen (BitLocker, GPO, RDP, Domain-Join) verfügbar zu machen.',
bitLockerOn:'BitLocker ist aktiviert ({method}).',bitLockerOff:'BitLocker ist nicht aktiviert.',riskBitLockerOk:'Die Systemfestplatte ist verschlüsselt, Datenverlust bei Diebstahl/Verlust ist eingeschränkt.',riskBitLockerOff:'Ohne Verschlüsselung sind Daten bei Geräteverlust oder -diebstahl ungeschützt.',recBitLockerEnable:'BitLocker aktivieren und Recovery-Key sicher hinterlegen (z. B. Entra ID / AD).',
defenderOff:'Windows Defender ist deaktiviert.',defenderRtOff:'Echtzeitschutz ist deaktiviert.',defenderSignatureOld:'Virendefinitionen sind {age} Tage alt.',defenderOk:'Windows Defender ist aktiv und aktuell.',riskDefenderOff:'Ohne aktiven Virenschutz besteht ein erhöhtes Malware-Risiko.',riskDefenderRtOff:'Ohne Echtzeitschutz werden Bedrohungen nicht sofort erkannt.',riskDefenderSignatureOld:'Veraltete Signaturen verringern die Erkennungsrate neuer Bedrohungen.',riskDefenderOk:'Keine Auffälligkeit erkannt.',recDefenderEnable:'Windows Defender oder eine gleichwertige Antivirus-Lösung aktivieren.',recDefenderRtEnable:'Echtzeitschutz aktivieren.',recDefenderUpdate:'Virendefinitionen aktualisieren.',
firewallAllOn:'Alle Firewall-Profile sind aktiv.',firewallPublicOff:'Firewall im öffentlichen Profil ist deaktiviert ({list}).',firewallSomeOff:'Firewall in einzelnen Profilen deaktiviert ({list}).',riskFirewallOk:'Keine Auffälligkeit erkannt.',riskFirewallPublicOff:'Ohne Firewall im öffentlichen Profil ist das Gerät in offenen Netzwerken exponiert.',riskFirewallSomeOff:'Deaktivierte Firewall-Profile erhöhen die Angriffsfläche.',recFirewallEnable:'Betroffene Firewall-Profile aktivieren.',
updateRecent:'Letztes erfolgreiches Update vor {days} Tagen.',updateAging:'Letztes erfolgreiches Update vor {days} Tagen.',updateStale:'Letztes erfolgreiches Update vor {days} Tagen.',updateServiceDisabled:'Der Windows-Update-Dienst (wuauserv) ist deaktiviert.',riskUpdateOk:'Updates werden regelmässig installiert.',riskUpdateAging:'Updates werden seltener als empfohlen installiert.',riskUpdateStale:'Lange ausstehende Updates erhöhen das Risiko bekannter Schwachstellen.',riskUpdateServiceDisabled:'Ohne laufenden Windows-Update-Dienst werden keine Updates installiert, unabhängig vom letzten Update-Datum.',recUpdateCheck:'Windows Update manuell ausführen und automatische Updates prüfen.',recUpdateServiceEnable:'Dienst "Windows Update" (wuauserv) aktivieren und Starttyp auf Automatisch/Manuell setzen.',
rdpDisabled:'Remotedesktop ist deaktiviert.',rdpEnabledNla:'Remotedesktop ist aktiviert, Network Level Authentication (NLA) erzwungen.',rdpEnabledNoNla:'Remotedesktop ist aktiviert, NLA ist nicht erzwungen.',riskRdpOk:'Keine Angriffsfläche über RDP.',riskRdpEnabledNla:'RDP ist erreichbar, aber durch NLA zusätzlich abgesichert.',riskRdpEnabledNoNla:'RDP ist ohne NLA erreichbar, dies erhöht das Risiko von Brute-Force- und Relay-Angriffen erheblich.',recRdpReview:'Prüfen, ob RDP-Zugriff nötig ist, und auf VPN/Bastion-Zugriff beschränken.',recRdpNla:'Network Level Authentication (NLA) für RDP erzwingen oder RDP deaktivieren, falls nicht benötigt.',
credGuardOn:'Credential Guard ist aktiv.',credGuardAvailable:'Virtualization Based Security ist verfügbar, Credential Guard ist jedoch nicht aktiv.',credGuardUnsupported:'Credential Guard / VBS ist nicht ermittelbar oder wird nicht unterstützt.',riskCredGuardOk:'Anmeldeinformationen sind zusätzlich gegen Pass-the-Hash-Angriffe geschützt.',riskCredGuardAvailable:'Ohne aktives Credential Guard sind Anmeldeinformationen im Arbeitsspeicher weniger geschützt. Bei einem Intune-verwalteten Firmengerät sollte dies über Richtlinie erzwungen werden.',recCredGuardEnable:'Credential Guard über Gruppenrichtlinie oder Intune aktivieren, sofern die Hardware dies unterstützt. Zur Tiefenprüfung: gpresult /r und systeminfo | findstr /i "Virtualization" (siehe technische Details).',
exclusionsNone:'Keine Defender-Ausschlüsse konfiguriert.',exclusionsNeedsAdmin:'Defender-Ausschlüsse konnten ohne Administratorrechte nicht ausgelesen werden.',recExclusionsRunAsAdmin:'Assessment als Administrator ausführen, um Defender-Ausschlüsse zuverlässig zu prüfen.',exclusionsItem:'{type}: {value}',riskExclusionsOk:'Ein Vollscan durchsucht alle Pfade, Prozesse und Dateitypen ohne blinde Flecken.',riskExclusionsFound:'Malware trägt sich häufig selbst in die Defender-Ausschlüsse ein, um von Scans übersehen zu werden. Dieser Ausschluss ist ein potenzieller blinder Fleck.',recExclusionsReview:'Ausschluss einzeln begründen und dokumentieren; falls nicht mehr benötigt, entfernen. Falls bewusst gewollt: unten als akzeptiert markieren.',
lapsDetected:'LAPS (Windows LAPS oder Legacy) wurde lokal erkannt.',lapsNotDetected:'Kein LAPS-Eintrag lokal gefunden.',riskLapsOk:'Lokale Administrator-Passwörter werden voraussichtlich rotiert und zentral verwaltet.',riskLapsMissing:'Ohne LAPS können lokale Administrator-Passwörter geräteübergreifend identisch und langlebig sein.',recLapsDeploy:'Windows LAPS über Intune/GPO ausrollen, sofern nicht bereits zentral verwaltet.',
cpuArm:'{name} (ARM-Prozessor).',cpuCompatible:'{name}, gemäss Namenskonvention vermutlich Windows-11-kompatibel.',cpuLikelyIncompatible:'{name}, gemäss Namenskonvention vermutlich zu alt für Windows 11.',cpuUnknown:'{name}, Kompatibilität nicht automatisch bestimmbar.',riskCpuOk:'Keine Auffälligkeit erkannt.',riskCpuIncompatible:'Ältere CPU-Generationen werden von Windows 11 offiziell nicht unterstützt.',recCpuCheck:'CPU-Modell gegen die offizielle Microsoft-Kompatibilitätsliste prüfen (automatische Schätzung anhand des Modellnamens, keine Garantie).',
ramStorageOk:'{ram} GB RAM, {size} GB Systemlaufwerk.',ramTooLow:'Nur {ram} GB RAM erkannt.',storageTooSmall:'Nur {size} GB Systemlaufwerk-Kapazität erkannt.',riskRamStorageOk:'Erfüllt die Windows-11-Mindestanforderungen (4 GB RAM, 64 GB Speicher).',riskRamTooLow:'Windows 11 benötigt mindestens 4 GB RAM.',riskStorageTooSmall:'Windows 11 benötigt mindestens 64 GB Speicherkapazität.',recRamUpgrade:'Arbeitsspeicher aufrüsten oder Geräteersatz einplanen.',recStorageUpgrade:'Systemlaufwerk vergrössern/ersetzen oder Geräteersatz einplanen.',
m365JoinStatus:'Geräteanbindung: {join}.',m365JoinStatusManaged:'Geräteanbindung: {join}. Gerät ist Entra-joined und wird per Intune/MDM verwaltet.',riskM365Managed:'Richtlinien (Compliance, Konfiguration) greifen zentral über Intune - das ist die erwartete, gute Ausgangslage für ein Firmengerät.',
versionCurrent:'Windows-Version {display} entspricht dem zum Skriptstand aktuellen Release.',versionBehind:'Windows-Version {display} liegt hinter dem zum Skriptstand aktuellen Release {latest} zurück.',versionAhead:'Windows-Version {display} ist neuer als das zum Skriptstand aktuelle Release (z. B. Insider/Preview-Kanal).',versionUnknown:'Windows-Version {display} konnte nicht automatisch eingeordnet werden.',versionWin10Eol:'Windows 10 wird eingesetzt; der Herstellersupport ist ausgelaufen (End of Life).',riskVersionOk:'Keine Auffälligkeit erkannt.',riskVersionBehind:'Ältere Feature-Updates erhalten Sicherheitsupdates ggf. nur noch befristet und es fehlen neuere Sicherheitsfunktionen.',riskVersionAhead:'Keine Auffälligkeit erkannt.',riskVersionWin10Eol:'Ohne Herstellersupport werden keine Sicherheitsupdates mehr bereitgestellt, bekannte Schwachstellen bleiben dauerhaft offen.',recVersionUpdate:'Feature-Update über Windows Update oder WSUS/Intune auf die aktuelle Version einspielen.',recVersionCheckManual:'Aktuelle Version manuell gegen https://learn.microsoft.com/windows/release-health/ prüfen (automatischer Abgleich im Skript ggf. veraltet).',recVersionUpgradeWin11:'Upgrade auf Windows 11 einplanen, sofern Hardware kompatibel ist; andernfalls Geräteersatz vorsehen.',
batteryNotPresent:'Kein Akku erkannt (Desktop-Gerät oder AC-only).',batteryWearUnavailable:'Akku erkannt, Verschleisswert konnte nicht ermittelt werden (aktueller Ladestand: {chargePct}%).',batteryHealthy:'Akkuverschleiss {wearPct}% (aktueller Ladestand: {chargePct}%).',batteryWornWarning:'Akkuverschleiss {wearPct}%, spürbarer Kapazitätsverlust.',batteryWornCritical:'Akkuverschleiss {wearPct}%, deutlicher Kapazitätsverlust.',riskBatteryOk:'Der Akku ist in gutem Zustand.',riskBatteryWornWarning:'Reduzierte Akkulaufzeit ist zu erwarten, aber kein akuter Handlungsbedarf.',riskBatteryWornCritical:'Deutlich reduzierte Akkulaufzeit; der Akku sollte ersetzt werden.',recBatteryReplace:'Akkutausch einplanen.',recBatteryMonitor:'Akkuzustand im Auge behalten, Tausch mittelfristig einplanen.'
};
function tr(k,a={}){let s=T[k]||k;for(const [x,y] of Object.entries(a||{}))s=s.replaceAll('{'+x+'}',String(y));return s}
function decode(){const bin=atob(DATA_B64);const bytes=new Uint8Array([...bin].map(c=>c.charCodeAt(0)));return JSON.parse(new TextDecoder('utf-8').decode(bytes))}
function esc(v){return String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]))}
function pctColor(p){return p>=90?'var(--green)':p>=70?'var(--yellow)':'var(--red)'}
function textOf(f,w){return w==='evidence'?tr(f.evidenceKey,f.evidenceArgs):w==='risk'?tr(f.riskKey):tr(f.recommendationKey)}
const COMPANY_ONLY_CHECKS=['lapsStatus','credentialGuard'];
function fid(f){return f.categoryKey+'::'+f.checkKey+(f.itemKey?'::'+f.itemKey:'')}
function ackKey(){return 'workplaceassessment-ack::'+data.computer}
function loadAck(){try{ackState=JSON.parse(localStorage.getItem(ackKey())||'{}')}catch(e){ackState={}}}
function saveAck(){try{localStorage.setItem(ackKey(),JSON.stringify(ackState))}catch(e){}}
function modeKey(){return 'workplaceassessment-devicemode::'+data.computer}
function loadMode(){let m=null;try{m=localStorage.getItem(modeKey())}catch(e){}deviceMode=(m==='company'||m==='private')?m:(data.suggestedDeviceMode==='company'?'company':'private')}
function saveMode(){try{localStorage.setItem(modeKey(),deviceMode)}catch(e){}}
function isCompanyOnlyExcluded(f){return deviceMode==='private'&&COMPANY_ONLY_CHECKS.includes(f.checkKey)}
function effMax(f){return isCompanyOnlyExcluded(f)?0:f.maxScore}
function effScore(f){if(isCompanyOnlyExcluded(f))return 0;const a=ackState[fid(f)];return (a&&a.acked)?f.maxScore:f.score}
function computeScoring(){
 const cats={};
 for(const f of (data.findings||[])){
  const m=effMax(f);if(!(m>0))continue;
  if(!cats[f.categoryKey])cats[f.categoryKey]={score:0,max:0,count:0};
  cats[f.categoryKey].score+=effScore(f);cats[f.categoryKey].max+=m;cats[f.categoryKey].count++
 }
 for(const k of Object.keys(cats)){const c=cats[k];c.percent=c.max>0?Math.round((c.score/c.max)*100):0;c.counted=TOTAL_CATEGORIES.includes(k)}
 let ts=0,tm=0;for(const k of TOTAL_CATEGORIES){if(cats[k]){ts+=cats[k].score;tm+=cats[k].max}}
 return {categories:cats,score:ts,max:tm,percent:tm>0?Math.round((ts/tm)*100):0}
}
function ackCount(){return Object.values(ackState).filter(a=>a&&a.acked).length}
function setDeviceMode(m){deviceMode=m;saveMode();renderModeSwitch();renderCards();renderTable()}
function renderModeSwitch(){
 modeSwitch.innerHTML=`<b>${esc(T.modeSwitchLabel)}</b>
  <label><input type="checkbox" ${deviceMode==='private'?'checked':''} id="modePrivateCb"> ${esc(T.modePrivate)}</label>
  <label><input type="checkbox" ${deviceMode==='company'?'checked':''} id="modeCompanyCb"> ${esc(T.modeCompany)}</label>`;
 document.getElementById('modePrivateCb').onchange=()=>setDeviceMode('private');
 document.getElementById('modeCompanyCb').onchange=()=>setDeviceMode('company');
}
function init(){
 data=decode();loadAck();loadMode();
 title.textContent=T.title;printBtn.textContent=T.print;overallLabel.textContent=T.overall;sectionTitle.textContent=T.section;hint.textContent=T.hint;q.placeholder=T.search;expandBtn.textContent=T.expand;collapseBtn.textContent=T.collapse;jsonBtn.textContent=T.json;thStatus.textContent=T.status;thCategory.textContent=T.category;thCheck.textContent=T.check;thScore.textContent=T.score;thEvidence.textContent=T.evidence;thRisk.textContent=T.risk;thRecommendation.textContent=T.recommendation;
 meta.textContent=`${data.user} @ ${data.computer} | ${data.completed} | ${T.admin}: ${data.admin?T.yes:T.no} | ${T.language}: ${data.lang}`;
 footer.textContent=`Assessment Engine ${data.version} | ${data.computer} | ${data.completed}`;
 renderModeSwitch();renderCards();renderTabs();renderTable()
}
function card(n,p,counted){return `<div class="card${counted===false?' optional':''}"><div class="donut" style="background:conic-gradient(${pctColor(p)} ${p}%,#25324a 0)"><div class="donutInner">${p}%</div></div><h3>${esc(n)}</h3>${counted===false?`<div class="optionalTag">${T.notCounted}</div>`:''}</div>`}
function renderCards(){
 const s=computeScoring();
 cards.innerHTML='';for(const k of CATEGORY_ORDER){if(s.categories[k])cards.innerHTML+=card(tr(k),s.categories[k].percent,s.categories[k].counted)}
 cards.innerHTML+=card(T.overall,s.percent,true);
 score.textContent=s.percent+'%';
 const n=ackCount();
 if(n>0){adjustedNote.style.display='block';adjustedNote.textContent=tr('adjustedScoreNote',{n,orig:data.scoring.percent})}else{adjustedNote.style.display='none'}
}
function renderTabs(){const vals=['all','critical','warning','info','ok'];tabs.innerHTML='';for(const t of vals){const b=document.createElement('button');b.className='tab'+(filter===t?' active':'');b.textContent=t==='all'?T.all:tr(t);b.onclick=()=>{filter=t;renderTabs();renderTable()};tabs.appendChild(b)}}
function impact(f){return (f.maxScore||0)-(f.score||0)}
function match(f,qv){if(!qv)return true;return [tr(f.categoryKey),tr(f.checkKey),tr(f.statusKey),textOf(f,'evidence'),textOf(f,'risk'),textOf(f,'recommendation'),(f.details||[]).join(' ')].join(' ').toLowerCase().includes(qv.toLowerCase())}
function scoreCellHtml(f){
 if(isCompanyOnlyExcluded(f))return `<span class="scoreOrig">${esc(f.score)} / ${esc(f.maxScore)}</span><span class="ackBadge">${esc(T.companyOnlyNote)}</span>`;
 const a=ackState[fid(f)];
 if(a&&a.acked)return `<span class="scoreOrig">${esc(f.score)} / ${esc(f.maxScore)}</span>${esc(f.maxScore)} / ${esc(f.maxScore)}<span class="ackBadge">${T.ackBadge}</span>`;
 return `${esc(f.score)} / ${esc(f.maxScore)}`
}
function ackBoxHtml(f){
 if(!(f.maxScore>0)||isCompanyOnlyExcluded(f))return '';
 const key=fid(f),a=ackState[key]||{acked:false,reason:'',ts:''};
 const savedMeta=a.acked&&a.ts?`<span class="ackMeta">${esc(T.ackSavedPrefix)} ${esc(a.ts)}</span>`:'';
 return `<div class="ackBox" onclick="event.stopPropagation()"><div class="ackRow">
  <label><input type="checkbox" data-ackcheck="${esc(key)}" ${a.acked?'checked':''}> ${esc(T.ackLabel)}</label>
  <input type="text" class="ackReason" data-ackreason="${esc(key)}" placeholder="${esc(T.ackReasonPlaceholder)}" value="${esc(a.reason||'')}">
  ${a.acked?`<button class="btn secondary" data-ackreset="${esc(key)}">${esc(T.ackReset)}</button>`:''}
 </div>${savedMeta}</div>`
}
function onAckCheck(cb){
 const key=cb.getAttribute('data-ackcheck');
 const row=cb.closest('.details');const reasonInput=row.querySelector('[data-ackreason="'+key+'"]');
 const reason=(reasonInput?reasonInput.value:'').trim();
 if(cb.checked&&!reason){alert(T.ackNeedsReason);cb.checked=false;return}
 ackState[key]=cb.checked?{acked:true,reason,ts:new Date().toLocaleString()}:{acked:false,reason,ts:''};
 saveAck();renderTable();renderCards()
}
function onAckReasonChange(input){
 const key=input.getAttribute('data-ackreason');const existing=ackState[key]||{acked:false,reason:'',ts:''};
 ackState[key]={...existing,reason:input.value.trim()};saveAck()
}
function onAckReset(btn){
 const key=btn.getAttribute('data-ackreset');delete ackState[key];saveAck();renderTable();renderCards()
}
function renderTable(){
 const openIds=new Set([...tbody.querySelectorAll('.details.open')].map(x=>x.id));
 tbody.innerHTML='';const qv=q.value;
 for(const f of (data.findings||[]).sort((a,b)=>impact(b)-impact(a))){
  if(filter!=='all'&&f.statusKey!==filter)continue;
  if(!match(f,qv))continue;
  const id='d_'+fid(f).replace(/[^a-zA-Z0-9]/g,'_');
  const isOpen=openIds.has(id);
  const acked=ackState[fid(f)]&&ackState[fid(f)].acked;
  const r=document.createElement('tr');r.className='row'+(isOpen?' selected':'');r.onclick=()=>{r.classList.toggle('selected');document.getElementById(id).classList.toggle('open')};
  r.innerHTML=`<td><span class="badge ${esc(f.statusKey)}">${esc(tr(f.statusKey))}</span>${acked?`<span class="ackBadge">${T.ackBadge}</span>`:''}</td><td>${esc(tr(f.categoryKey))}</td><td>${esc(tr(f.checkKey))}</td><td>${scoreCellHtml(f)}</td><td>${esc(textOf(f,'evidence'))}</td><td>${esc(textOf(f,'risk'))}</td><td>${esc(textOf(f,'recommendation'))}</td>`;
  tbody.appendChild(r);
  const d=document.createElement('tr');d.id=id;d.className='details'+(isOpen?' open':'');
  d.innerHTML=`<td colspan="7"><div class="summary"><b>${T.technical}</b></div><div class="pre">${esc((f.details&&f.details.length)?f.details.join('\n'):T.noDetails)}</div>${ackBoxHtml(f)}</td>`;
  tbody.appendChild(d)
 }
 tbody.querySelectorAll('[data-ackcheck]').forEach(cb=>cb.onchange=()=>onAckCheck(cb));
 tbody.querySelectorAll('[data-ackreason]').forEach(inp=>inp.onchange=()=>onAckReasonChange(inp));
 tbody.querySelectorAll('[data-ackreset]').forEach(btn=>btn.onclick=(e)=>{e.stopPropagation();onAckReset(btn)})
}
function expandAll(){document.querySelectorAll('.details').forEach(x=>x.classList.add('open'))}
function collapseAll(){document.querySelectorAll('.details').forEach(x=>x.classList.remove('open'));document.querySelectorAll('.row').forEach(x=>x.classList.remove('selected'))}
function downloadJson(){const s=computeScoring();const out={...data,adjustedScoring:s,acknowledgements:ackState};const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(out,null,2)],{type:'application/json'}));a.download=`Assessment_${data.computer}_${data.completed}.json`;a.click()}
try{init()}catch(e){err.style.display='block';err.textContent=T.renderError+(e&&e.stack?e.stack:e)}
</script></body></html>
'@
$html=$html.Replace('__DATA_B64__',$b64);[IO.File]::WriteAllText($HtmlPath,$html,$Utf8NoBom);Write-Host "Assessment complete" -ForegroundColor Cyan;Write-Host "JSON: $JsonPath";Write-Host "HTML: $HtmlPath";if(-not $NoOpen){Start-Process $HtmlPath}
# Checks like BitLocker call native tools (manage-bde) whose non-zero exit code would otherwise
# leak as this script's own exit code (e.g. GitHub Actions' pwsh runner fails a step on a stray
# non-zero $LASTEXITCODE even though every check here degrades gracefully on its own).
$global:LASTEXITCODE=0
