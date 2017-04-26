﻿param($installPath, $toolsPath, $package, $project)


function PathToUri([string] $path)
{
    return new-object Uri('file://' + $path.Replace("%","%25").Replace("#","%23").Replace("$","%24").Replace("+","%2B").Replace(",","%2C").Replace("=","%3D").Replace("@","%40").Replace("~","%7E").Replace("^","%5E"))
}

function UriToPath([System.Uri] $uri)
{
    return [System.Uri]::UnescapeDataString( $uri.ToString() ).Replace([System.IO.Path]::AltDirectorySeparatorChar, [System.IO.Path]::DirectorySeparatorChar)
}

$targetsFile = [System.IO.Path]::Combine($toolsPath, 'PostSharp.targets')

# Need to load MSBuild assembly if it's not loaded yet.
Add-Type -AssemblyName 'Microsoft.Build, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a'

# Grab the loaded MSBuild project for the project
$msbuild = [Microsoft.Build.Evaluation.ProjectCollection]::GlobalProjectCollection.GetLoadedProjects($project.FullName) | Select-Object -First 1

# Make the path to the targets file relative.
$projectUri = PathToUri $project.FullName
$targetUri = PathToUri $targetsFile

$relativePath = UriToPath $projectUri.MakeRelativeUri($targetUri)

# Remove elements from previous installations or versions.
$itemsToRemove = @()
$itemsToRemove += $msbuild.Xml.Properties | Where-Object {$_.Name.ToLowerInvariant() -eq "dontimportpostsharp" }
# $itemsToRemove += $msbuild.Xml.Properties | Where-Object {$_.Name.ToLowerInvariant().EndsWith("postsharpignoredpackages") } # Don't remove this so that it stays during upgrades.
$itemsToRemove += $msbuild.Xml.Imports | Where-Object {$_.Project.ToLowerInvariant().EndsWith("postsharp.targets") } 
$itemsToRemove += $msbuild.Xml.Targets | Where-Object {$_.Name.ToLowerInvariant() -eq "ensurepostsharpimported" }


if ($itemsToRemove -and $itemsToRemove.length)
{
    foreach ($itemToRemove in $itemsToRemove)
    {
        $itemToRemove.Parent.RemoveChild($itemToRemove) | out-null
    }
}

# Remove references from PostSharp 1.* and 2.*.
$referencesToRemove = @()
$referencesToRemove += $project.Object.References | Where-Object {$_.Identity.ToLowerInvariant().StartsWith("postsharp.public") } 
$referencesToRemove += $project.Object.References | Where-Object {$_.Identity.ToLowerInvariant().StartsWith("postsharp.laos") } 

if ($referencesToRemove -and $referencesToRemove.length)
{
    foreach ($referenceToRemove in $referencesToRemove)
    {
        $referenceToRemove.Remove()
    }
}



# Set property DontImportPostSharp to prevent locally-installed previous versions of PostSharp to interfere.
$msbuild.Xml.AddProperty( "DontImportPostSharp", "True" ) | Out-Null

# Add import to PostSharp.targets
$import = $msbuild.Xml.AddImport($relativePath)
$import.set_Condition( "Exists('$relativePath')" ) | Out-Null
[string]::Format("Added import of '{0}'.", $relativePath )

 # Add a target to fail the build when our targets are not imported
$target = $msbuild.Xml.AddTarget("EnsurePostSharpImported")
$target.BeforeTargets = "BeforeBuild"
$target.Condition = "'`$(PostSharp30Imported)' == ''"

# if the targets don't exist at the time the target runs, package restore didn't run
$errorTask = $target.AddTask("Error")
$errorTask.Condition = "!Exists('$relativePath')"
$errorTask.SetParameter("Text", "This project references NuGet package(s) that are missing on this computer. Enable NuGet Package Restore to download them.  For more information, see http://www.postsharp.net/links/nuget-restore.");

# if the targets exist at the time the target runs, package restore ran but the build didn't import the targets.
$errorTask = $target.AddTask("Error")
$errorTask.Condition = "Exists('$relativePath')"
$errorTask.SetParameter("Text", "The build restored NuGet packages. Build the project again to include these packages in the build. For more information, see http://www.postsharp.net/links/nuget-restore.");

# For all the assembly references installed by this package - set CopyLocal = true
$pakcageRefs = $package.AssemblyReferences | %{$_.Name}
foreach ($reference in $project.Object.References)
{
    if ($pakcageRefs -contains $reference.Name + ".dll")
    {
        # To persist the CopyLocal value we have to change it from true to false first
        $reference.CopyLocal = $false;
        $reference.CopyLocal = $true;
    }
}

$project.Save()
$project.Object.Refresh()

# SIG # Begin signature block
# MIIaCQYJKoZIhvcNAQcCoIIZ+jCCGfYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUM66m4nh9OcfxIym8ysLbDzX7
# 746gghTBMIIEmTCCA4GgAwIBAgIPFojwOSVeY45pFDkH5jMLMA0GCSqGSIb3DQEB
# BQUAMIGVMQswCQYDVQQGEwJVUzELMAkGA1UECBMCVVQxFzAVBgNVBAcTDlNhbHQg
# TGFrZSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxITAfBgNV
# BAsTGGh0dHA6Ly93d3cudXNlcnRydXN0LmNvbTEdMBsGA1UEAxMUVVROLVVTRVJG
# aXJzdC1PYmplY3QwHhcNMTUxMjMxMDAwMDAwWhcNMTkwNzA5MTg0MDM2WjCBhDEL
# MAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UE
# BxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxKjAoBgNVBAMT
# IUNPTU9ETyBTSEEtMSBUaW1lIFN0YW1waW5nIFNpZ25lcjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBAOnpPd/XNwjJHjiyUlNCbSLxscQGBGue/YJ0UEN9
# xqC7H075AnEmse9D2IOMSPznD5d6muuc3qajDjscRBh1jnilF2n+SRik4rtcTv6O
# KlR6UPDV9syR55l51955lNeWM/4Og74iv2MWLKPdKBuvPavql9LxvwQQ5z1IRf0f
# aGXBf1mZacAiMQxibqdcZQEhsGPEIhgn7ub80gA9Ry6ouIZWXQTcExclbhzfRA8V
# zbfbpVd2Qm8AaIKZ0uPB3vCLlFdM7AiQIiHOIiuYDELmQpOUmJPv/QbZP7xbm1Q8
# ILHuatZHesWrgOkwmt7xpD9VTQoJNIp1KdJprZcPUL/4ygkCAwEAAaOB9DCB8TAf
# BgNVHSMEGDAWgBTa7WR0FJwUPKvdmam9WyhNizzJ2DAdBgNVHQ4EFgQUjmstM2v0
# M6eTsxOapeAK9xI1aogwDgYDVR0PAQH/BAQDAgbAMAwGA1UdEwEB/wQCMAAwFgYD
# VR0lAQH/BAwwCgYIKwYBBQUHAwgwQgYDVR0fBDswOTA3oDWgM4YxaHR0cDovL2Ny
# bC51c2VydHJ1c3QuY29tL1VUTi1VU0VSRmlyc3QtT2JqZWN0LmNybDA1BggrBgEF
# BQcBAQQpMCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20w
# DQYJKoZIhvcNAQEFBQADggEBALozJEBAjHzbWJ+zYJiy9cAx/usfblD2CuDk5oGt
# Joei3/2z2vRz8wD7KRuJGxU+22tSkyvErDmB1zxnV5o5NuAoCJrjOU+biQl/e8Vh
# f1mJMiUKaq4aPvCiJ6i2w7iH9xYESEE9XNjsn00gMQTZZaHtzWkHUxY93TYCCojr
# QOUGMAu4Fkvc77xVCf/GPhIudrPczkLv+XZX4bcKBUCYWJpdcRaTcYxlgepv84n3
# +3OttOe/2Y5vqgtPJfO44dXddZhogfiqwNGAwsTEOYnB9smebNd0+dmX+E/CmgrN
# Xo/4GengpZ/E8JIh5i15Jcki+cPwOoRXrToW9GOUEB1d0MYwggTTMIIDu6ADAgEC
# AhAY2tGeJn3ou0ohWM3MaztKMA0GCSqGSIb3DQEBBQUAMIHKMQswCQYDVQQGEwJV
# UzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWduIFRy
# dXN0IE5ldHdvcmsxOjA4BgNVBAsTMShjKSAyMDA2IFZlcmlTaWduLCBJbmMuIC0g
# Rm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxRTBDBgNVBAMTPFZlcmlTaWduIENsYXNz
# IDMgUHVibGljIFByaW1hcnkgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkgLSBHNTAe
# Fw0wNjExMDgwMDAwMDBaFw0zNjA3MTYyMzU5NTlaMIHKMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWduIFRydXN0
# IE5ldHdvcmsxOjA4BgNVBAsTMShjKSAyMDA2IFZlcmlTaWduLCBJbmMuIC0gRm9y
# IGF1dGhvcml6ZWQgdXNlIG9ubHkxRTBDBgNVBAMTPFZlcmlTaWduIENsYXNzIDMg
# UHVibGljIFByaW1hcnkgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkgLSBHNTCCASIw
# DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK8kCAgpejWeYAyq50s7Ttx8vDxF
# HLsr4P4pAvlXCKNkhRUn9fGtyDGJXSLoKqqmQrOP+LlVt7G3S7P+j34HV+zvQ9tm
# YhVhz2ANpNje+ODDYgg9VBPrScpZVIUm5SuPG5/r9aGRwjNJ2ENjalJL0o/ocFFN
# 0Ylpe8dw9rPcEnTbe11LVtOWvxV3obD0oiXyrxySZxjl9AYE75C55ADk3Tq1Gf8C
# uvQ87uCL6zeL7PTXrPL28D2v3XWRMxkdHEDLdCQZIZPZFP6sKlLHj9UESeSNY0eI
# PGmDy/5HvSt+T8WVrg6d1NFDwGdz4xQIfuU/n3O4MwrPXT80h5aK7lPoJRUCAwEA
# AaOBsjCBrzAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjBtBggrBgEF
# BQcBDARhMF+hXaBbMFkwVzBVFglpbWFnZS9naWYwITAfMAcGBSsOAwIaBBSP5dMa
# hqyNjmvDz4Bq1EgYLHsZLjAlFiNodHRwOi8vbG9nby52ZXJpc2lnbi5jb20vdnNs
# b2dvLmdpZjAdBgNVHQ4EFgQUf9Nlp8Ld7LvwMAnzQzn6Aq8zMTMwDQYJKoZIhvcN
# AQEFBQADggEBAJMkSjBfYs/YGpgvPercmS29d/aleSI47MSnoHgSrWIORXBkxeeX
# Zi2YCX5fr9bMKGXyAaoIGkfe+fl8kloIaSAN2T5tbjwNbtjmBpFAGLn4we3f20Gq
# 4JYgyc1kFTiByZTuooQpCxNvjtsM3SUC26SLGUTSQXoFaUpYT2DKfoJqCwKqJRc5
# tdt/54RlKpWKvYbeXoEWgy0QzN79qIIqbSgfDQvE5ecaJhnh9BFvELWV/OdCBTLb
# zp1RXii2noXTW++lfUVAco63DmsOBvszNUhxuJ0ni8RlXw2GdpxEevaVXPZdMggz
# pFS2GD9oXPJCSoU4VINf0egs8qwR1qjtY2owggU7MIIEI6ADAgECAhBtVZzZIav2
# n7DtBg0fBzVhMA0GCSqGSIb3DQEBBQUAMIG0MQswCQYDVQQGEwJVUzEXMBUGA1UE
# ChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWduIFRydXN0IE5ldHdv
# cmsxOzA5BgNVBAsTMlRlcm1zIG9mIHVzZSBhdCBodHRwczovL3d3dy52ZXJpc2ln
# bi5jb20vcnBhIChjKTEwMS4wLAYDVQQDEyVWZXJpU2lnbiBDbGFzcyAzIENvZGUg
# U2lnbmluZyAyMDEwIENBMB4XDTE0MDYxMjAwMDAwMFoXDTE3MDgxMDIzNTk1OVow
# bTELMAkGA1UEBhMCQ1oxDzANBgNVBAgTBlByYWd1ZTEPMA0GA1UEBxMGUHJhZ3Vl
# MR0wGwYDVQQKFBRTaGFycENyYWZ0ZXJzIHMuci5vLjEdMBsGA1UEAxQUU2hhcnBD
# cmFmdGVycyBzLnIuby4wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC+
# b1Bbdq+VGj6EJcdDpYvUSiSDkZJZTocyzilpOHyt2zUNY69ywv6yRwbF7Ik7wC+M
# QCULUQdl11/LnAufJcydQsSsKG1qfW2MSozrcB/s11GW5uQWbOMkwIiTc+dHIeak
# uTiYw9un+DmCSqT9+CUNqadsMHSsBGrA2NmyKf307qkxxoFqcZhqHaS7EPf+luvU
# 6FZuU8G4l2D+P1WzfhOcGod4gUFlBWdy8cT6bB3WwFgXnKLgajUn+MdPbextgate
# zBQ/FEr1O0KYI/oymKOqpaqMiqxD76ZRqayPBlkPPZCcBVTlgnIgzAzCsjmo1xrJ
# 3hTjrxYE2gJUmh8TXZK5AgMBAAGjggGNMIIBiTAJBgNVHRMEAjAAMA4GA1UdDwEB
# /wQEAwIHgDArBgNVHR8EJDAiMCCgHqAchhpodHRwOi8vc2Yuc3ltY2IuY29tL3Nm
# LmNybDBmBgNVHSAEXzBdMFsGC2CGSAGG+EUBBxcDMEwwIwYIKwYBBQUHAgEWF2h0
# dHBzOi8vZC5zeW1jYi5jb20vY3BzMCUGCCsGAQUFBwICMBkWF2h0dHBzOi8vZC5z
# eW1jYi5jb20vcnBhMBMGA1UdJQQMMAoGCCsGAQUFBwMDMFcGCCsGAQUFBwEBBEsw
# STAfBggrBgEFBQcwAYYTaHR0cDovL3NmLnN5bWNkLmNvbTAmBggrBgEFBQcwAoYa
# aHR0cDovL3NmLnN5bWNiLmNvbS9zZi5jcnQwHwYDVR0jBBgwFoAUz5mp6nsm9EvJ
# jo/X8AUm7+PSp50wHQYDVR0OBBYEFEI5jc+chSpGcqlmayYzSF3yHjQ1MBEGCWCG
# SAGG+EIBAQQEAwIEEDAWBgorBgEEAYI3AgEbBAgwBgEBAAEB/zANBgkqhkiG9w0B
# AQUFAAOCAQEApG4uGyuFmvEbeoSDvt+5U04XH8Nlq9iscLMeeijHVJA6gFi3kzqg
# EPdshu4UDT7+CQunXXqsx8daGnksxiYMtj1OOVMlLWUKTnFqK2mbIEbM14RaTg/G
# IcpJPj3xnIn+sobQiaWISQs30oG7FByla7yzTAGXNM721F0/O6owD9dmCV42QvVz
# zTh9aJDtxyQtFd1ZW8v4IhgCFtLMpOcE4PQvn/tJXP+ExLC60RiwE/kgN/3hxiop
# oOZrVB5r/lbCPI93PC2nQ6QYr+EXn2siWTMCJ3o+C0uRV8Pe8yFrdDMlNkevIAHq
# NxCVayNXKRO7fKmQLcbREcKaZUn9z6Wa5zCCBgowggTyoAMCAQICEFIA5aolVvwa
# hu2WydRLM8cwDQYJKoZIhvcNAQEFBQAwgcoxCzAJBgNVBAYTAlVTMRcwFQYDVQQK
# Ew5WZXJpU2lnbiwgSW5jLjEfMB0GA1UECxMWVmVyaVNpZ24gVHJ1c3QgTmV0d29y
# azE6MDgGA1UECxMxKGMpIDIwMDYgVmVyaVNpZ24sIEluYy4gLSBGb3IgYXV0aG9y
# aXplZCB1c2Ugb25seTFFMEMGA1UEAxM8VmVyaVNpZ24gQ2xhc3MgMyBQdWJsaWMg
# UHJpbWFyeSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eSAtIEc1MB4XDTEwMDIwODAw
# MDAwMFoXDTIwMDIwNzIzNTk1OVowgbQxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5W
# ZXJpU2lnbiwgSW5jLjEfMB0GA1UECxMWVmVyaVNpZ24gVHJ1c3QgTmV0d29yazE7
# MDkGA1UECxMyVGVybXMgb2YgdXNlIGF0IGh0dHBzOi8vd3d3LnZlcmlzaWduLmNv
# bS9ycGEgKGMpMTAxLjAsBgNVBAMTJVZlcmlTaWduIENsYXNzIDMgQ29kZSBTaWdu
# aW5nIDIwMTAgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQD1I0te
# pdeKuzLp1Ff37+THJn6tGZj+qJ19lPY2axDXdYEwfwRof8srdR7NHQiM32mUpzej
# nHuA4Jnh7jdNX847FO6G1ND1JzW8JQs4p4xjnRejCKWrsPvNamKCTNUh2hvZ8eOE
# O4oqT4VbkAFPyad2EH8nA3y+rn59wd35BbwbSJxp58CkPDxBAD7fluXF5JRx1lUB
# xwAmSkA8taEmqQynbYCOkCV7z78/HOsvlvrlh3fGtVayejtUMFMb32I0/x7R9FqT
# KIXlTBdOflv9pJOZf9/N76R17+8V9kfn+Bly2C40Gqa0p0x+vbtPDD1X8TDWpjaO
# 1oB21xkupc1+NC2JAgMBAAGjggH+MIIB+jASBgNVHRMBAf8ECDAGAQH/AgEAMHAG
# A1UdIARpMGcwZQYLYIZIAYb4RQEHFwMwVjAoBggrBgEFBQcCARYcaHR0cHM6Ly93
# d3cudmVyaXNpZ24uY29tL2NwczAqBggrBgEFBQcCAjAeGhxodHRwczovL3d3dy52
# ZXJpc2lnbi5jb20vcnBhMA4GA1UdDwEB/wQEAwIBBjBtBggrBgEFBQcBDARhMF+h
# XaBbMFkwVzBVFglpbWFnZS9naWYwITAfMAcGBSsOAwIaBBSP5dMahqyNjmvDz4Bq
# 1EgYLHsZLjAlFiNodHRwOi8vbG9nby52ZXJpc2lnbi5jb20vdnNsb2dvLmdpZjA0
# BgNVHR8ELTArMCmgJ6AlhiNodHRwOi8vY3JsLnZlcmlzaWduLmNvbS9wY2EzLWc1
# LmNybDA0BggrBgEFBQcBAQQoMCYwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLnZl
# cmlzaWduLmNvbTAdBgNVHSUEFjAUBggrBgEFBQcDAgYIKwYBBQUHAwMwKAYDVR0R
# BCEwH6QdMBsxGTAXBgNVBAMTEFZlcmlTaWduTVBLSS0yLTgwHQYDVR0OBBYEFM+Z
# qep7JvRLyY6P1/AFJu/j0qedMB8GA1UdIwQYMBaAFH/TZafC3ey78DAJ80M5+gKv
# MzEzMA0GCSqGSIb3DQEBBQUAA4IBAQBWIuY0pMRhy0i5Aa1WqGQP2YyRxLvMDOWt
# eqAif99HOEotbNF/cRp87HCpsfBP5A8MU/oVXv50mEkkhYEmHJEUR7BMY4y7oTTU
# xkXoDYUmcwPQqYxkbdxxkuZFBWAVWVE5/FgUa/7UpO15awgMQXLnNyIGCb4j6T9E
# mh7pYZ3MsZBc/D3SjaxCPWU21LQ9QCiPmxDPIybMSyDLkB9djEw0yjzY5TfWb6Ug
# vTTrJtmuDefFmvehtCGRM2+G6Fi7JXx0Dlj+dRtjP84xfJuPG5aexVN2hFucrZH6
# rO2Tul3IIVPCglNjrxINUIcRGz1UUpaKLJw9khoImgUux5OlSJHTMYIEsjCCBK4C
# AQEwgckwgbQxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5WZXJpU2lnbiwgSW5jLjEf
# MB0GA1UECxMWVmVyaVNpZ24gVHJ1c3QgTmV0d29yazE7MDkGA1UECxMyVGVybXMg
# b2YgdXNlIGF0IGh0dHBzOi8vd3d3LnZlcmlzaWduLmNvbS9ycGEgKGMpMTAxLjAs
# BgNVBAMTJVZlcmlTaWduIENsYXNzIDMgQ29kZSBTaWduaW5nIDIwMTAgQ0ECEG1V
# nNkhq/afsO0GDR8HNWEwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKA
# AKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFAdEh3ZEhh44H4/871oMpKUR
# 3H/oMA0GCSqGSIb3DQEBAQUABIIBALdtQ44NIggtpItEiIwMRaQYnzb/tj/t78r4
# ei5KXAPqlr1k393TmO4pr1f57VuwjfU2+K8PjxpaY4s4MZLvzDJnwLSREhfrBZp1
# /6gwg6APJ/4++GWUuP/eU33b1xg2l0vGYCU/Dy4ASDmQ8bliSyCAFAZluibui72C
# ZhtJulmGNtq4myI8PhZ20k6DqhVUj3d6MwQ2c/dold+EjoYOky04g9Wy6yemh82b
# 1oBVMTyXoehF9bq/KqG+djr91ERbtsdjIkxcopwVyk8Q9GmZTPmQprETirTLWU3A
# CCvWL7u+RmvEr2UbtocHCtpOViwsl8d4o279+aCWjpis3msgbF6hggJDMIICPwYJ
# KoZIhvcNAQkGMYICMDCCAiwCAQEwgakwgZUxCzAJBgNVBAYTAlVTMQswCQYDVQQI
# EwJVVDEXMBUGA1UEBxMOU2FsdCBMYWtlIENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEhMB8GA1UECxMYaHR0cDovL3d3dy51c2VydHJ1c3QuY29t
# MR0wGwYDVQQDExRVVE4tVVNFUkZpcnN0LU9iamVjdAIPFojwOSVeY45pFDkH5jML
# MAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3
# DQEJBTEPFw0xNzA0MjEwODU2MjNaMCMGCSqGSIb3DQEJBDEWBBTb22sqLKaPZsYI
# hSF75mY5iDxv2zANBgkqhkiG9w0BAQEFAASCAQBMjacpVAL3w+mgaOL2TZe/zV9H
# /TjNBqLNuPidVIOxqx06tIHWkOO6ULo8GNXowQuc4sjkvMgmRvALr98Z/3JwH0pj
# T81zGmMeec7vKKhD4voHf4UtnpxMS8jAXJN0nQJeOCKk993nS/Gv4GhoqehovqN7
# kGC/rMs51fM7HVOG7p4SziWYYhB1myVXi5Yw3x6e79ZnlUTXWIXI65hYSosoBPI3
# pa3FiHa1Zp1unCcvUs1ZwAvnsHEMs7YD+BzV3dtS+MHPK1qAnNe1ONAuZYeaPara
# 2OGbQwly8CFmfhZLk0mY1LL7LccKTJasvmaS6AxOJYbThKHx/bZCfBqA0ZwB
# SIG # End signature block
