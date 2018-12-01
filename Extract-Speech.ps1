$tmp = Get-Content .\create-soundfiles.sh -Encoding UTF8 | select -Skip 10 | ? {$_ -like "say*" -or $_ -like "*.mp3"}
$MySpeech = @()

$tmp | % {
    $tmpm = $_ -match '(^say.*) \"(.*)\".*-o (.*)\.aiff'
    If ($tmpm) {
        $Mysay = $Matches[2]
        $tmpm = $tmp | ? { $_ -like "lame*" -and $_ -like "*"+$Matches[3]+".wav*"}
        if ($tmpm.count -eq 1) {
            $tmpm2 = $tmpm -match '^lame.*wav (.*)'
            if ($tmpm2) {
                $Myfile = $Matches[1]
            }
        }
    }
    if ($Mysay -and $Myfile) {
        $obj = New-Object PSObject
        $obj | Add-Member -MemberType NoteProperty -Name fileorg -Value $Myfile
        $obj | Add-Member -MemberType NoteProperty -Name text -Value $Mysay
        $MySpeech += $obj
    }
    $Mysay = ""
    $Myfile = ""
}

$MySpeech | convertto-Csv -NoTypeInformation -Delimiter "|" | select -Skip 1 | % {$_.Replace('"','')} | Set-Content  ".\speech.txt" -Force -Encoding UTF8