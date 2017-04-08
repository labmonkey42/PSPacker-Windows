using namespace System.Text
using namespace System.Xml
Import-Module $PSScriptRoot\WindowsMachine.psm1

Function Generate-AutoUnattend
{
[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$true)]
    [WindowsMachine]$Machine,
    [Parameter(Mandatory=$false)]
    [string]$filename = "AutoUnattend.xml",
    [Parameter()]
    [switch]$WhatIf
)
    [XmlDocument]$document = $Machine.GenerateAutoUnattendXml()
    [StringBuilder]$builder = [StringBuilder]::new()
    [StringWriter]$stringWriter = [StringWriter]::new($builder)
    [XmlTextWriter]$xmlWriter = [XmlTextWriter]::new($stringWriter)
    
    $xmlWriter.Formatting = [Formatting]::Indented
    $document.Save($xmlWriter)
    $xmlWriter.Close()
    $stringWriter.Dispose()
    
    if ($WhatIf)
    {
        Write-Output "The following XML would be written to $($filename):"
        Write-Output
        $builder.ToString()
    }
    else
    {
        Set-Content -Path $filename -Value $builder.ToString()
    }
}
