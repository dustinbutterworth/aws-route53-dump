#!/usr/bin/env pwsh
$csvfile = "records.csv"
$allresults = @()
$awsprofile = Read-Host "Please enter your aws profile"
$account = (Get-STSCallerIdentity -Region us-east-1 -ProfileName $awsprofile).account
Write-Host "Checking for hosted zones in $awsprofile"
$hostedzones = Get-R53HostedZoneList -ProfileName $awsprofile
foreach ($zone in $hostedzones) {
    $nextIdentifier = $null
    $nextType = $null
    $nextName = $null
    [System.Collections.ArrayList] $result = @()
    write-host "Getting records from zone: $($zone.Id)"
    do {
        $recordSet = Get-R53ResourceRecordSet -MaxItem 10 -ProfileName $awsprofile -HostedZoneId $zone.Id -StartRecordIdentifier $nextIdentifier -StartRecordName $nextName -StartRecordType $nextType
        $recordSet.ResourceRecordSets | ForEach-Object {
            $name = $_.Name
            $type = $_.Type
            if ($_.AliasTarget.DNSName) {
                # for each value create separate object
                $_.AliasTarget.DNSName | ForEach-Object {
                    [void] $result.add(
                        [PSCustomObject]@{
                            account = $account
                            name    = $name
                            type    = $type
                            value   = $_
                        }
                    )
                }
            }
            elseif ($_.value -isnot [String]) {
                # for each value create separate object
                $_.ResourceRecords.Value | ForEach-Object {
                    [void] $result.add(
                        [PSCustomObject]@{
                            account = $account
                            name    = $name
                            type    = $type
                            value   = $_
                        }
                    )
                }
            }
            else {
                # value is string, there is no need to expand it
                [void] $result.add(
                    [PSCustomObject]@{
                        account = $account
                        name    = $name
                        type    = $type
                        value   = $_.value
                    }
                )
            }
        }
        if ($recordSet.IsTruncated) {
            $nextIdentifier = $recordSet.NextRecordIdentifier
            $nextType = $recordSet.NextRecordType
            $nextName = $recordSet.NextRecordName
        }
    } while ($recordSet.IsTruncated)
    $allresults += $result
}

$allresults | Export-Csv -path ($csvfile) -NoTypeInformation