<code></code><code>PowerShell
Param
  (
    [switch] $ShowAvailableWinSpeechVoices = $false
  )




#Import 
$MySpeech = Import-Csv .\speech.txt -Delimiter "|" -Header file, text -Encoding UTF8

# Destination directory
$Basepath = "C:\temp\MySpeech"

# Configure Windows Speech Engine
$GenerateWinSpeech = $true # $true / $false 
$GenerateWinSpeechVoice="Microsoft Hedda Desktop" # Find available voices with parameter -ShowAvailableWinSpeechVoices
$FFMPEGPath = "C:\windows\system32\ffmpeg.exe" # We need to convert output wav-files to mp3. 

#Configure Amazon Polly Engine
$GenerateAmazonPolly = $true # $true / $false 
$GenerateAmazonPollyVoice= "Vicki","Marlene","Hans" # Select Voices https://docs.aws.amazon.com/polly/latest/dg/voicelist.html

#Configure Google Text2Speech Engine
$GenerateGoogleTTS = $true # $true / $false
$GenerateGoogleTTSVoice="de-DE-Wavenet-A","de-DE-Wavenet-B","de-DE-Wavenet-C","de-DE-Wavenet-D" # Select Voices https://cloud.google.com/text-to-speech/docs/voices
$GoogleTTSspeakingRate="1.20" # https://cloud.google.com/text-to-speech/docs/reference/rest/v1/text/synthesize#audioconfig
$GoogleTTSpitch="0" # https://cloud.google.com/text-to-speech/docs/reference/rest/v1/text/synthesize#audioconfig

$GoogleAPIToken ="<yourapikey>"



#####################################################################


Add-Type -AssemblyName System.speech
$MSspeak = New-Object System.Speech.Synthesis.SpeechSynthesizer


#add numbers to object
1..2 | % {
    $tmp='{0:d4}' -f $_ 
    $obj = New-Object PSObject
    $obj | Add-Member -MemberType NoteProperty -Name text -Value $_
    $obj | Add-Member -MemberType NoteProperty -Name file -Value $($tmp + ".mp3")
     $MySpeech += $obj

}


#$Myspeech | fl *


if ($ShowAvailableWinSpeechVoices) { # List availables windows voices and exit 
    $MSspeak.GetInstalledVoices().VoiceInfo | ? {$_.Culture -like "de-DE"} | select Gender,Name,Description | fl # Only DE Voices
    exit 0
}




#Init Speech Engines
if ($GenerateWinSpeech) {
    $MSspeakPath = $Basepath + "\MSSpeak"
    if (!(test-path($MSspeakPath))) { New-Item -Path $MSspeakPath -ItemType Directory }
}

if ($GenerateAmazonPolly) {
    If ( ! (Get-module awspowershell )) {Import-Module awspowershell}
    $AmazonPollyPath = $Basepath + "\AmazonPolly"
    if (!(test-path($AmazonPollyPath))) { New-Item -Path $AmazonPollyPath -ItemType Directory }
}

if ($GenerateGoogleTTS) {
    $GoogleTTSPath = $Basepath + "\GoogleTTS"
    if (!(test-path($GoogleTTSPath))) { New-Item -Path $GoogleTTSPath -ItemType Directory }
}

foreach ($ToSpeak in $MySpeech) {

    write-host $ToSpeak.text

    if ($GenerateWinSpeech) {
        foreach ($Voice in $GenerateWinSpeechVoice) {
            $mytmppath=$MSspeakPath + "\" + $voice
            if (!(Test-Path($mytmppath))){new-item $mytmppath -ItemType Directory}
            $mytmppath += "\" + $ToSpeak.file
            if (!(Test-Path($mytmppath))) {
                $MSspeak = New-Object System.Speech.Synthesis.SpeechSynthesizer
                $MSspeak.SelectVoice($Voice)
                $MSspeak.SetOutputToWaveFile($mytmppath + ".wav")
                $MSspeak.Speak($ToSpeak.text)
                $MSspeak.Dispose()
                $FFMPEGArg = "-i """ + $mytmppath + ".wav"" -id3v2_version 3 -f mp3 -ab 128k -ar 44100 """ + $mytmppath +""""
                
                Start-Process -Wait -FilePath $FFMPEGPath -ArgumentList $FFMPEGArg -WindowStyle Hidden
                Remove-Item ($mytmppath + ".wav")
            } else {
                write-host "   -> MSSpeak $Voice already done."
            }
        }

    }
   
    if ($GenerateAmazonPolly) {

        foreach ($Voice in $GenerateAmazonPollyVoice) {
            $mytmppath=$AmazonPollyPath + "\" + $voice 
            if (!(Test-Path($mytmppath))){new-item $mytmppath -ItemType Directory}
            $mytmppath += "\" + $ToSpeak.file
            if (!(Test-Path($mytmppath))) { 
                $tmp=Get-POLSpeech -Text $ToSpeak.text -VoiceId $voice -OutputFormat mp3
                $mytmpfile=[System.IO.FileStream]::new($mytmppath, [System.IO.FileMode]::OpenOrCreate)
                $tmp.AudioStream.CopyTo($mytmpfile)
                $mytmpfile.close()
                write-host "   -> AmazonPolly - $Voice"
            } else {
                write-host "   -> AmazonPolly - $Voice - already done."
            }
        }

    

    }


    if ($GenerateGoogleTTS) {
        foreach ($voice in $GenerateGoogleTTSVoice) {
            $mytmppath=$GoogleTTSPath + "\" + $voice 
            if (!(Test-Path($mytmppath))){new-item $mytmppath -ItemType Directory}
            $mytmppath += "\" + $ToSpeak.file
            if (!(Test-Path($mytmppath))) { 
                $tmp=@{input=@{text="$($ToSpeak.text)"};voice=@{languageCode="de-DE";name="$($voice)"};audioConfig=@{audioEncoding="MP3";speakingRate="$GoogleTTSspeakingRate";pitch="$GoogleTTSPitch";'sampleRateHertz'="44100"}}
                $tmp = $tmp | ConvertTo-Json
                #write-host $tmp
                $Myrequest=Invoke-WebRequest -Uri "https://texttospeech.googleapis.com/v1/text:synthesize?fields=audioContent&key=$($GoogleAPIToken)" -ContentType "application/json; charset=utf-8" -Method Post -Body $tmp
                if ($Myrequest) {
                    $tmp=($Myrequest.content | ConvertFrom-Json).audiocontent
                    $tmp = [Convert]::FromBase64String($tmp)
                    [IO.File]::WriteAllBytes($mytmppath, $tmp)

                    write-host "   -> GoogleTTS - $Voice"
                    


                } else {
                    write-host "   -> ERROR GoogleTTS $Voice"
                }
                
                
            } else {
                write-host "   -> GoogleTTS - $Voice - already done."
            }



        }

        











    }

}



</code><code></code>

