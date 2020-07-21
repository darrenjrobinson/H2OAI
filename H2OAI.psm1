$CommandsToExport = @()

function Start-H2O {
        <#
.SYNOPSIS
Start H2O

.DESCRIPTION
Start H2O

.PARAMETER H2oPath
Path of H2o.jar
e.g. c:\h2o\h2o-3.28.0.1\h2o-3.28.0.1\h2o.jar

.INPUTS
H2O Path
c:\h2o\h2o-3.28.0.1\h2o-3.28.0.1\h2o.jar

.OUTPUTS
Nothing.  Starts H2O

.EXAMPLE
Start-H2o c:\h2o\h2o-3.28.0.1\h2o-3.28.0.1\h2o.jar

.LINK
https://blog.darrenjrobinson.com/

#>

    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $H2oPath
    )

    try {
        $out = &"java" -version 2>&1
        $out[0].tostring()
    
        if ($out[0].tostring() -notlike 'java version "1.8*' ) {
            Write-Error "Incorrect Java Version detected. Found $($out[0].tostring()). Java 1.8 is required."
            break 
        }
        else {
            if (Test-Path $H2oPath) {
                $Global:javaPID = Start-Process "java" "-jar $($H2oPath)" -PassThru
            }
            else {
                Write-Error "$($H2oPath) not found."
                break 
            }
        }
    }
    catch {    
        Write-Error "Java not detected. Ensure Java 1.8 is installed and configured in the environment path."
        break 
    }
}
$CommandsToExport += 'Start-H2O'

function Stop-H2O {
    <#
.SYNOPSIS
    Stop H2O

.DESCRIPTION
    Stop H2O

.PARAMETER processID
    (optional) PID of the java process set when starting H2O. By default this is set to a global variable and passed automatically to Stop-H2O.

.EXAMPLE
    Stop-H2O
    Stop-H2O -processID 12345

.LINK
    https://blog.darrenjrobinson.com/

#>

    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [String] $processID = $Global:javaPID.Id
    )

    try {
        Stop-Process -Id $processID
    }
    catch {
        Write-Error $_
        break 
    }
}
$CommandsToExport += 'Stop-H2O'

function ConvertTo-FormData {
    <#
.SYNOPSIS
    Parse Data into an H2O Dataframe

.DESCRIPTION
    Parse Data into an H2O Dataframe

.PARAMETER InputObject
    PowerShell Object for H2O Dataframe

.INPUTS
    PowerShell Object with values

    source_frames  : 
    parse_type     : 
    separator      : 44
    number_columns : 
    single_quotes  : 
    column_names   : 
    column_types   : 
    check_header   : 
    chunk_size     : 

.OUTPUTS
    Form Data for posting to H2O as a Dataframe

.EXAMPLE
    "Parse the data into a real H2o dataframe"
    $parse_url = $url -f "Parse"
    $parse_body = $ret | Select-Object source_frames, parse_type, separator, number_columns, single_quotes, column_names, column_types, check_header, chunk_size | ConvertTo-FormData
    $parse_body += "&destination_frame=dataSet&delete_on_done=true"
    $ret = Invoke-RestMethod $parse_url -Method Post -Body $parse_body

.LINK
    https://powertoe.wordpress.com/2017/10/23/h2o-machine-learning-with-powershell/

#>

    param(
        [Parameter(ValueFromPipeline = $true)] 
        [PSObject] $InputObject
    )
    

    Begin {
        $output = ""
    }
    Process {
        foreach ($prop in $InputObject.psobject.properties | Select-Object -expandproperty name) {
            if ($InputObject.($prop).gettype().name -eq "Boolean") {
                if ($InputObject.($prop)) {
                    $output += "$prop=true&"
                }
                else {
                    $output += "$prop=false&"
                }
            } if ($InputObject.($prop).gettype().isarray) {
                if ($InputObject.($prop).name) {
                    $output += "$prop=[{0}]&" -f ($InputObject.($prop).name -join ",")
                }
                else {
                    $output += "$prop=[{0}]&" -f ($InputObject.($prop) -join ",")
                }
            }
            else {
                $output += "$prop=" + $InputObject.($prop) + "&"
            }
        }
    }
    End {
        $output.Remove($output.Length - 1, 1)
    }
}
$CommandsToExport += 'ConvertTo-FormData'

function Wait-H2OJob {
        <#
.SYNOPSIS
    Wait for an H2O Job to complete

.DESCRIPTION
    Wait for an H2O Job to complete

.PARAMETER JobPath
    URL of H2O Job
    e.g. /3/Jobs/$0301c0a8018532d4ffffffff$_ae64f3e55ac939c97697016b66ee4652

.INPUTS
    H2O Job Path
    /3/Jobs/$0301c0a8018532d4ffffffff$_ae64f3e55ac939c97697016b66ee4652

.OUTPUTS
    Nothing.  Sleep loop for job completion 

.EXAMPLE
    Wait-H2OJob $ret.job.key.URL

.LINK
    https://powertoe.wordpress.com/2017/10/23/h2o-machine-learning-with-powershell/

#>

    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $JobPath
    )


    $notdone = $true
    while ($notdone) {
        $status = invoke-restmethod ("http://localhost:54321" + $JobPath) | Select-Object -ExpandProperty jobs | Select-Object -ExpandProperty status

        if ($status -eq "DONE") {
            $notdone = $false
        }
        else {
            Start-Sleep -Milliseconds 1000
        }
    }
}
$CommandsToExport += 'Wait-H2OJob'

function Get-H2OPrediction {
    <#
.SYNOPSIS
    Get an H2O Prediction for a dataset and a sample data request

.DESCRIPTION
    Get an H2O Prediction for a dataset and a sample data request

.PARAMETER url
    H2O URL 
    default: "http://localhost:54321/3/{0}"

.PARAMETER dataset
    H2O Dataset to build model from

.PARAMETER predictData
    Data to build a prediction for

.PARAMETER predictColumn
    Column to provide prediction on

.PARAMETER modelAlgorithm
    Algorithm to build H2O model 
    default: 'glm'

.PARAMETER modelSplit
    Split of Model Dataset between Train and Test
    e.g ".85,.15" 

.EXAMPLE
    Get-H2OPrediction -url "http://localhost:54321/3/{0}" -dataset "c:\Data\v2\dataSet.csv" -predictData = "c:\Data\v2\predictDataSet.csv" -modelAlgorithm = 'glm' -modelSplit = ".85,.15"

.LINK
    http://darrenjrobinson.com/
#>

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true,
            Mandatory = $false)]
        [string]$url = "http://localhost:54321/3/{0}",
        [Parameter(ValueFromPipeline = $true,
            Mandatory = $true)]
        [string]$dataset,
        [Parameter(ValueFromPipeline = $true,
            Mandatory = $true)]
        [string]$predictData,
        [Parameter(ValueFromPipeline = $true,
            Mandatory = $false)]
            [ValidateSet('glm', 'gbm', '"glrm', 'aggregator', 'deeplearning', 'drf', 'isolationforest', 'kmeans', 'naivebayes', 'pca', 'targetencoder', 'word2vec')]
        [string]$modelAlgorithm = "glm",
        [Parameter(ValueFromPipeline = $true,
            Mandatory = $false)]
        [string]$modelSplit = ".85,.15",
        [Parameter(ValueFromPipeline = $true,
            Mandatory = $true)]
        [string]$predictColumn 
    )
    Process {    
        try {         
            
            $responseTemplate = [pscustomobject][ordered]@{ 
                prediction      = $null  
                modelType       = $null  
                modelConfidence = $null 
            }                 
            
            $importfiles_url = $url -f "ImportFiles"
            $importfiles_body = "path=$dataset"
            $ret = Invoke-RestMethod $importfiles_url -Method POST -Body $importfiles_body

            # Run parse setup to find out how H2o thinks it should parse the data
            $parsesetup_url = $url -f "ParseSetup"
            $parsesetup_body = 'source_frames=[{0}]' -f $ret.destination_frames[0]
            $ret = $null 
            $ret = Invoke-RestMethod $parsesetup_url -Method Post -Body $parsesetup_body           

            # Parse the data into a real H2o dataframe
            $parse_url = $url -f "Parse"
            $parse_body = $ret | Select-Object source_frames, parse_type, separator, number_columns, single_quotes, column_names, column_types, check_header, chunk_size | ConvertTo-FormData
            $parse_body += "&destination_frame=dataSet&delete_on_done=true"
            $ret = $null 
            $ret = Invoke-RestMethod $parse_url -Method Post -Body $parse_body
            wait-H2oJob $ret.job.key.URL

            # Split the Data into Training and Test DF's
            $splitframe_url = $url -f "SplitFrame"
            $splitframe_body = "dataset=dataSet&ratios=[$($modelSplit)]&destination_frames=[train,validate]"
            $ret = $null 
            $ret = invoke-restmethod $splitframe_url -Method Post -Body $splitframe_body
            wait-H2oJob $ret.key.URL

            # Build a Model
            $model_url = $url -f "ModelBuilders/$($modelAlgorithm)"            
            $model_body = "training_frame=train&validation_frame=validate&response_column=$($predictColumn)&model_id=$($modelAlgorithm)"
            $ret = $null 
            $ret = invoke-restmethod $model_url -Method Post -Body $model_body
            wait-H2oJob $ret.job.key.URL

            # Prediction Quality # Validation Data
            $predict_url = $url -f "Predictions/models/$($modelAlgorithm)/frames/validate"
            $ret = $null 
            $ret = invoke-restmethod $predict_url -method POST -Body "predictions_frame=predicted_validate_data"
            $modelConfidence = $ret.model_metrics | Select-Object -expandproperty MSE

            # Predict New Close Data based off last close data
            $importfiles_url = $url -f "ImportFiles"
            $importfiles_body = "path=$($predictData)"
            $ret = $null 
            $ret = Invoke-RestMethod $importfiles_url -Method POST -Body $importfiles_body

            # Run parse setup to find out how H2o thinks it should parse the data
            $parsesetup_url = $url -f "ParseSetup"
            $parsesetup_body = 'source_frames=[{0}]' -f $ret.destination_frames[0]
            $ret = $null 
            $ret = Invoke-RestMethod $parsesetup_url -Method Post -Body $parsesetup_body

            # Parse the data into a real H2o dataframe"
            $parse_url = $url -f "Parse"
            $parse_body = $ret | Select-Object source_frames, parse_type, separator, number_columns, single_quotes, column_names, column_types, check_header, chunk_size | ConvertTo-FormData
            $parse_body += "&destination_frame=predictme&delete_on_done=true"
            $ret = $null 
            $ret = Invoke-RestMethod $parse_url -Method Post -Body $parse_body
            Wait-H2oJob $ret.job.key.URL

            # Leverage the data model we built earlier to predict against this new data frame
            $predict_url = $url -f "Predictions/models/$($modelAlgorithm)/frames/predictme"
            $ret = $null 
            $ret = invoke-restmethod $predict_url -method POST -Body "predictions_frame=predictme_results"
            $modelType = $ret.model_metrics.model_category 

            $results_url = $url -f "Frames/predictme_results"
            $ret = $null 
            $ret = invoke-restmethod $results_url
            $prediction = $null 
            $prediction = $ret.frames.columns | Select-Object label, data 

            $predictionResult = $responseTemplate.PsObject.Copy()
            # $predictionResult.prediction = $prediction.data[0] 
            $predictionResult.prediction = $prediction
            $predictionResult.modelType = $modelType
            $predictionResult.modelConfidence = $modelConfidence

            return $predictionResult
        }
        catch {
            return "Error returning Prediction. $($_)"
        }    
    }    
}
$CommandsToExport += 'Get-H2OPrediction'
Export-ModuleMember -Function $CommandsToExport

# SIG # Begin signature block
# MIIX8wYJKoZIhvcNAQcCoIIX5DCCF+ACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUBkNlmxP6bJfA2eLbfB5GnSIa
# /+6gghMmMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggUwMIIEGKADAgECAhAECRgbX9W7ZnVTQ7VvlVAIMA0GCSqGSIb3DQEBCwUAMGUx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9v
# dCBDQTAeFw0xMzEwMjIxMjAwMDBaFw0yODEwMjIxMjAwMDBaMHIxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNp
# Z25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQD407Mcfw4R
# r2d3B9MLMUkZz9D7RZmxOttE9X/lqJ3bMtdx6nadBS63j/qSQ8Cl+YnUNxnXtqrw
# nIal2CWsDnkoOn7p0WfTxvspJ8fTeyOU5JEjlpB3gvmhhCNmElQzUHSxKCa7JGnC
# wlLyFGeKiUXULaGj6YgsIJWuHEqHCN8M9eJNYBi+qsSyrnAxZjNxPqxwoqvOf+l8
# y5Kh5TsxHM/q8grkV7tKtel05iv+bMt+dDk2DZDv5LVOpKnqagqrhPOsZ061xPeM
# 0SAlI+sIZD5SlsHyDxL0xY4PwaLoLFH3c7y9hbFig3NBggfkOItqcyDQD2RzPJ6f
# pjOp/RnfJZPRAgMBAAGjggHNMIIByTASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1Ud
# DwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDAzB5BggrBgEFBQcBAQRtMGsw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcw
# AoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBP
# BgNVHSAESDBGMDgGCmCGSAGG/WwAAgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93
# d3cuZGlnaWNlcnQuY29tL0NQUzAKBghghkgBhv1sAzAdBgNVHQ4EFgQUWsS5eyoK
# o6XqcQPAYPkt9mV1DlgwHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8w
# DQYJKoZIhvcNAQELBQADggEBAD7sDVoks/Mi0RXILHwlKXaoHV0cLToaxO8wYdd+
# C2D9wz0PxK+L/e8q3yBVN7Dh9tGSdQ9RtG6ljlriXiSBThCk7j9xjmMOE0ut119E
# efM2FAaK95xGTlz/kLEbBw6RFfu6r7VRwo0kriTGxycqoSkoGjpxKAI8LpGjwCUR
# 4pwUR6F6aGivm6dcIFzZcbEMj7uo+MUSaJ/PQMtARKUT8OZkDCUIQjKyNookAv4v
# cn4c10lFluhZHen6dGRrsutmQ9qzsIzV6Q3d9gEgzpkxYz0IGhizgZtPxpMQBvwH
# gfqL2vmCSfdibqFT+hKUGIUukpHqaGxEMrJmoecYpJpkUe8wggVVMIIEPaADAgEC
# AhAM7NF1d7OBuRMX7VCjxmCvMA0GCSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25p
# bmcgQ0EwHhcNMjAwNjE0MDAwMDAwWhcNMjMwNjE5MTIwMDAwWjCBkTELMAkGA1UE
# BhMCQVUxGDAWBgNVBAgTD05ldyBTb3V0aCBXYWxlczEUMBIGA1UEBxMLQ2hlcnJ5
# YnJvb2sxGjAYBgNVBAoTEURhcnJlbiBKIFJvYmluc29uMRowGAYDVQQLExFEYXJy
# ZW4gSiBSb2JpbnNvbjEaMBgGA1UEAxMRRGFycmVuIEogUm9iaW5zb24wggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDCPs8uaOSScUDQwhtE/BxPUnBT/FRn
# pQUzLoBTKW0YSKAxUbEURehXJuNBfAj2GGnMOHaB3EvdbxXl1NfLOo3wtRdro04O
# MjOH56Al/9+Rc6DNY48Pl9Ogvuabglah+5oDC/YOYjZS2C9AbBGGRTFjeGHT4w0N
# LLPbxyoTF/wfqZNNy5p+C7823gDR12OvWFgEdTiDnVkn3phxGy8xlK7yrJwFQ0Sn
# z8RknEFSaoKnuYqLvaOiOSG77q6M4+LbGAbwhYToaqWa4xWFFJS8XsX0+t6LA+0a
# Kb3ZEb1GyfySDW2TFf/V1RhuM4iBc6YTUUCj9BTqcpWKgkw2k2xUQHP9AgMBAAGj
# ggHFMIIBwTAfBgNVHSMEGDAWgBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAdBgNVHQ4E
# FgQU6HpAuSSJdceLWep4ajN6JIQcAOgwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQM
# MAoGCCsGAQUFBwMDMHcGA1UdHwRwMG4wNaAzoDGGL2h0dHA6Ly9jcmwzLmRpZ2lj
# ZXJ0LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3JsMDWgM6Axhi9odHRwOi8vY3Js
# NC5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDBMBgNVHSAERTBD
# MDcGCWCGSAGG/WwDATAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2Vy
# dC5jb20vQ1BTMAgGBmeBDAEEATCBhAYIKwYBBQUHAQEEeDB2MCQGCCsGAQUFBzAB
# hhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTgYIKwYBBQUHMAKGQmh0dHA6Ly9j
# YWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURDb2RlU2ln
# bmluZ0NBLmNydDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IBAQA1agcO
# M3seD1Cs5pnHRXwwrhzieRgF4UMJgDI/9KrBh4C0o8DsXvaa+YlXoTdhmeKW/xv5
# i9mkVNmvD3wa3AKe5CNwiPc5kx96lC7BXWfdLoY7ejfTGkoa7qHR3gusmQhuZW+L
# dFmvtTyu4eqcjhOBthoJYp3B8tv8JR99pSxFfsE6C4VGdhKHAmZkDMiaAHHava9Z
# xl4+Uof+TuS6lQBZJjw8Xw76W93DNU9JUNb4+hOp8jir1q7/RTvtQ3QWr+iEzJD8
# JRfvfXF4LpFvlOOWYOF22EU/ciGjUVfQYi7nk/LnHzipb46747K1BwAVnHbYMDx0
# BRtLc/s4g9qZxTrxMYIENzCCBDMCAQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8G
# A1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQQIQ
# DOzRdXezgbkTF+1Qo8ZgrzAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUg+aTVjNXS9HNkSlq1zc+
# msi6FjowDQYJKoZIhvcNAQEBBQAEggEAcJp+mNhfiXfNyYFE7ETO3ZuceGZmez3K
# wvfLfHn2YLUVaRlI7y8JG1lebC85cLEkqAnOkRwfr9f4Hwa/HcBb6Ldz/a9wWyRN
# li6xV8x8Lx05wM7/nxUdRnBvaDVw3kmfn9cNIv/KbmcLMDjiYYQDkd6ZsoBr8bo8
# IMpNchJCYmvkXEhKeioi+5BJXS87zfI63ti+libnaWcG00zIrc9+9ktUkXwS2P06
# mzZvuQUx4s+5tQJ+a/rGkYSxoAfYS8zcmCwnf1lyodHBXEyCJtDcS8fsCZjQRf8W
# ZbRA5If05dncpSasF9nwxCOt680XUd1G9eu28eDH7mp9mc6h0UyrwaGCAgswggIH
# BgkqhkiG9w0BCQYxggH4MIIB9AIBATByMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQK
# ExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBT
# dGFtcGluZyBTZXJ2aWNlcyBDQSAtIEcyAhAOz/Q4yP6/NW4E2GqYGxpQMAkGBSsO
# AwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEP
# Fw0yMDA3MjEwNzUwNTBaMCMGCSqGSIb3DQEJBDEWBBTz7bedt7mt2Momc2v5viCx
# KlxspTANBgkqhkiG9w0BAQEFAASCAQAprdh+CayDzX7UtU7POzcm5iXGRUZxQFId
# qug6iRpRRilako4j42Fxm2J1tVz99Q1gCx2B3eNxhzEmpeiqbnvBJdFH9+kY8Ccl
# u+xTob9wEFdYAkv001Mtydt3fcsG/F0Z7jq5K+QQfmKhg+UpSIalZQywjMo2tY4m
# JIFai1ayYMD4uN70gbPsOLuXVaDNK/2IUK9ZSQavAzQo7bBITFjWkD7MbZH/xGtO
# 4YDEOprlmc5lt9ssYhwjRPNbF+SBm3upE64Inv4hPeQXgQCyKNPInohisLj8v8sn
# YArd6mIeYVwiwXpqBp/fZ6p0bC1lhSzUafL1NTxrEodAojGZbpKQ
# SIG # End signature block
