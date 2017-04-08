using module .\PSPacker\Machine.psm1
using module .\AutoUnattendSetupCommand.psm1
using namespace System.Collections.Generic
using namespace System.Xml

Class WindowsMachine : Machine
{
    
    WindowsMachine() : base()
    {
        $mytype = $this.GetType()
        if ($mytype -eq [WindowsMachine])
        {
            throw("Class $mytype is abstract and must be implemented")
        }

        $this.InitSetupCommands()
    }

    InitSetupCommands()
    {
        $this.SetupCommands = [List[AutoUnattendSetupCommand]]::new()
        
        $setupCommandsFilePath = "$PSScriptRoot\AutoUnattendSetupCommands.json"
        if (Test-Path $setupCommandsFilePath)
        {
            $commands = (Get-Content -Raw -Path $setupCommandsFilePath | ConvertFrom-Json).commands

            $commands | Foreach-Object
            {
                $command = [AutoUnattendSetupCommand]::new()
                
                $command.Command = $_.command
                $command.Description = $_.description
                if ($command.PSObject.Properties.Name -contains "requiresUserInput" -and [bool]($command.requiresUserInput) -eq $true)
                {
                    $command.RequiresUserInput = $true
                }

                $this.SetupCommands.Add($command)
            }
        }
    }

    [List[AutoUnattendSetupCommand]]$SetupCommands

    [string]$WinrmUsername = "vagrant"

    [string]$WinrmPassword = "vagrant"

    [string]$ProductKey = ""

    [XmlDocument]GenerateAutoUnattendXml()
    {
        [XmlDocument]$document = [XMLDocument]::new()
    
        [XmlNode]$declaration = $document.CreateXmlDeclaration("1.0", "utf-8")
        $document.AppendChild($declaration)
    
        [XMLElement]$unattend = $document.CreateElement($null, "unattend", "urn:schemas-microsoft-com:unattend")
        $document.AppendChild($unattend)
    
        $unattend.AppendChild($document.CreateElement("servicing"))
    
        [XmlElement]$windowspeSettings = $this.GenerateAutoUnattendWinpeSettings($document)
        $unattend.AppendChild($windowspeSettings)
    
        [XmlElement]$offlineServicingSettings = $this.GenerateAutoUnattendOfflineServicingSettings()
        $unattend.AppendChild($offlineServicingSettings)
    
        [XmlElement]$oobeSystemSettings = $this.GenerateAutoUnattendOobeSystemSettings($document)
        $unattend.AppendChild($oobeSystemSettings)
    
        [XmlElement]$specializeSettings = $this.GenerateAutoUnattendSpecializeSettings($document)
        $unattend.AppendChild($specializeSettings)

        return $document
    }

    [XmlElement]GenerateAutoUnattendWinpeSettings([XmlDocument]$document)
    {
        [XmlElement]$settings = $document.CreateElement("settings")
        $settings.SetAttribute("pass", "windowsPE")
    
        [XmlElement]$setupComponent = $this.GenerateAutoUnattendWinpeSettingsSetupComponent($document)
        $settings.AppendChild($setupComponent)

        [XmlElement]$coreComponent = $this.GenerateAutoUnattendWinpeSettingsInternationalizationComponent($document)
        $settings.AppendChild($coreComponent)

        return $settings
    }

    [XmlElement]GenerateAutoUnattendWinpeSettingsSetupComponent([XmlDocument]$document)
    {
        [XmlElement]$component = $document.CreateElement("component")
        $component.AppendChild($document.CreateAttribute("xmlns:wcm", "http://schemas.microsoft.com/WMIConfig/2002/State"))
        $component.AppendChild($document.CreateAttribute("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance"))
        $component.AppendChild($document.CreateAttribute("name", "Microsoft-Windows-Setup"))
        $component.AppendChild($document.CreateAttribute("processorArchitecture", "amd64"))
        $component.AppendChild($document.CreateAttribute("publicKeyToken", "31bf3856ad364e35"))
        $component.AppendChild($document.CreateAttribute("language", "neutral"))
        $component.AppendChild($document.CreateAttribute("versionScope", "nonSxS"))

        [XmlElement]$diskConfiguration = $this.GenerateAutoUnattendWinpeSettingsSetupComponentDiskConfiguration($document)
        $component.AppendChild($diskConfiguration)

        [XmlElement]$imageInstall = $this.GenerateAutoUnattendWinpeSettingsSetupComponentImageInstall($document)
        $component.AppendChild($imageInstall)
    
        [XmlElement]$winpeUserData = $document.CreateElement("UserData")
    
        [XmlElement]$userdataAcceptEula = $document.CreateElement("AcceptEula")
        $userdataAcceptEula.InnerText = "true"
        $winpeUserData.AppendChild($userdataAcceptEula)
    
        [XmlElement]$userdataFullName = $document.CreateElement("FullName")
        $userdataFullName.InnerText = $this.WinrmUsername
        $winpeUserData.AppendChild($userdataFullName)
    
        [XmlElement]$userdataOrganization = $document.CreateElement("Organization")
        $userdataOrganization.InnerText = ""
        $winpeUserData.AppendChild($userdataOrganization)
    
        [XmlElement]$userdataProductKey = $document.CreateElement("ProductKey")

        if (-not [String]::IsNullOrWhiteSpace($this.ProductKey))
        {
            [XmlElement]$key = $document.CreateElement("Key")
            $key.InnerText = $this.ProductKey
            $userdataProductKey.AppendChild($key)
        }

        [XmlElement]$productKeyWillShowUi = $document.CreateElement("Key")
        $productKeyWillShowUi.InnerText = "Never"
        $userdataProductKey.AppendChild($productKeyWillShowUi)
    
        $winpeUserData.AppendChild($userdataProductKey)
    
        $component.AppendChild($winpeUserData)

        return $component
    }

    [XmlElement]GenerateAutoUnattendWinpeSettingsSetupComponentDiskConfiguration([XmlDocument]$document)
    {
        [XmlElement]$diskConfiguration = $document.CreateElement("DiskConfiguration")

        # TODO: Make disks and partitions configurable and utilize that here.

        [XmlElement]$disk = $document.CreateElement("Disk")

        [XmlElement]$createPartitions = $document.CreateElement("CreatePartitions")

        [XmlElement]$createPartitionBoot = $document.CreateElement("CreatePartition")
        $createPartitionBoot.AppendChild($document.CreateAttribute("wcm:action", "add"))

        [XmlElement]$createPartitionBootType = $document.CreateElement("Type")
        $createPartitionBootType.InnerText = "Primary"
        $createPartitionBoot.AppendChild($createPartitionBootType)

        [XmlElement]$createPartitionBootOrder = $document.CreateElement("Order")
        $createPartitionBootOrder.InnerText = "1"
        $createPartitionBoot.AppendChild($createPartitionBootOrder)

        [XmlElement]$createPartitionBootSize = $document.CreateElement("Size")
        $createPartitionBootSize.InnerText = "350"
        $createPartitionBoot.AppendChild($createPartitionBootSize)

        $createPartitions.AppendChild($createPartitionBoot)

        [XmlElement]$createPartitionSystem = $document.CreateElement("CreatePartition")
        $createPartitionSystem.AppendChild($document.CreateAttribute("wcm:action", "add"))

        [XmlElement]$createPartitionSystemType = $document.CreateElement("Type")
        $createPartitionSystemType.InnerText = "Primary"
        $createPartitionSystem.AppendChild($createPartitionSystemType)

        [XmlElement]$createPartitionSystemOrder = $document.CreateElement("Order")
        $createPartitionSystemOrder.InnerText = "1"
        $createPartitionSystem.AppendChild($createPartitionSystemOrder)

        [XmlElement]$createPartitionSystemExtend = $document.CreateElement("Extend")
        $createPartitionSystemExtend.InnerText = "true"
        $createPartitionSystem.AppendChild($createPartitionSystemExtend)

        $createPartitions.AppendChild($createPartitionSystem)

        $disk.AppendChild($createPartitions)
    
        $diskConfiguration.AppendChild($document.CreateAttribute("wcm:action", "add"))

        [XmlElement]$modifyPartitions = $document.CreateElement("ModifyPartitions")

        [XmlElement]$modifyPartitionBoot = $document.CreateElement("ModifyPartition")
        $modifyPartitionBoot.AppendChild($document.CreateAttribute("wcm:action", "add"))

        [XmlElement]$modifyPartitionBootActive = $document.CreateElement("Active")
        $modifyPartitionBootActive.InnerText = "true"
        $modifyPartitionBoot.AppendChild($modifyPartitionBootActive)

        [XmlElement]$modifyPartitionBootFormat = $document.CreateElement("Format")
        $modifyPartitionBootFormat.InnerText = "NTFS"
        $modifyPartitionBoot.AppendChild($modifyPartitionBootFormat)

        [XmlElement]$modifyPartitionBootLabel = $document.CreateElement("Label")
        $modifyPartitionBootLabel.InnerText = "boot"
        $modifyPartitionBoot.AppendChild($modifyPartitionBootLabel)

        [XmlElement]$modifyPartitionBootOrder = $document.CreateElement("Order")
        $modifyPartitionBootOrder.InnerText = "1"
        $modifyPartitionBoot.AppendChild($modifyPartitionBootOrder)

        [XmlElement]$modifyPartitionBootPartitionID = $document.CreateElement("PartitionID")
        $modifyPartitionBootPartitionID.InnerText = "1"
        $modifyPartitionBoot.AppendChild($modifyPartitionBootPartitionID)

        $modifyPartitions.AppendChild($modifyPartitionBoot)

        [XmlElement]$modifyPartitionSystem = $document.CreateElement("ModifyPartition")
        $modifyPartitionSystem.AppendChild($document.CreateAttribute("wcm:action", "add"))

        [XmlElement]$modifyPartitionSystemFormat = $document.CreateElement("Format")
        $modifyPartitionSystemFormat.InnerText = "NTFS"
        $modifyPartitionSystem.AppendChild($modifyPartitionSystemFormat)

        [XmlElement]$modifyPartitionSystemLabel = $document.CreateElement("Label")
        $modifyPartitionSystemLabel.InnerText = "System"
        $modifyPartitionSystem.AppendChild($modifyPartitionSystemLabel)

        [XmlElement]$modifyPartitionSystemLetter = $document.CreateElement("Letter")
        $modifyPartitionSystemLetter.InnerText = "C"
        $modifyPartitionSystem.AppendChild($modifyPartitionSystemLetter)

        [XmlElement]$modifyPartitionSystemOrder = $document.CreateElement("Order")
        $modifyPartitionSystemOrder.InnerText = "2"
        $modifyPartitionSystem.AppendChild($modifyPartitionSystemOrder)

        [XmlElement]$modifyPartitionSystemPartitionID = $document.CreateElement("PartitionID")
        $modifyPartitionSystemPartitionID.InnerText = "2"
        $modifyPartitionSystem.AppendChild($modifyPartitionSystemPartitionID)

        $modifyPartitions.AppendChild($modifyPartitionSystem)

        $disk.AppendChild($modifyPartitions)

        [XmlElement]$diskID = $document.CreateElement("DiskID")
        $diskID.InnerText = "0"
        $disk.AppendChild($diskID)

        [XmlElement]$willWipeDisk = $document.CreateElement("WillWipeDisk")
        $willWipeDisk.InnerText = "true"
        $disk.AppendChild($willWipeDisk)

        $diskConfiguration.AppendChild($disk)

        [XmlElement]$willShowUI = $document.CreateElement("WillShowUI")
        $willShowUI.InnerText = "OnError"
        $diskConfiguration.AppendChild($willShowUI)

        return $diskConfiguration
    }

    [XmlElement]GenerateAutoUnattendWinpeSettingsSetupComponentImageInstall([XmlDocument]$document)
    {
        [XmlElement]$imageInstall = $document.CreateElement("ImageInstall")

        [XmlElement]$osImage = $document.CreateElement("OSImage")

        [XmlElement]$installTo = $document.CreateElement("InstallTo")
    
        [XmlElement]$installToDiskID = $document.CreateElement("DiskID")
        $installToDiskID.InnerText = "0"
        $installTo.AppendChild($installToDiskID)

        [XmlElement]$installToPartitionID = $document.CreateElement("PartitionID")
        $installToPartitionID.InnerText = "2"
        $installTo.AppendChild($installToPartitionID)

        $osImage.AppendChild($installTo)

        [XmlElement]$willShowUI = $document.CreateElement("WillShowUI")
        $willShowUI.InnerText = "OnError"
        $osImage.AppendChild($willShowUI)

        [XmlElement]$installToAvailablePartition = $document.CreateElement("InstallToAvailablePartition")
        $installToAvailablePartition.InnerText = "false"
        $osImage.AppendChild($installToAvailablePartition)

        [XmlElement]$installFrom = $document.CreateElement("InstallFrom")

        [XmlElement]$metadata = $document.CreateElement("Metadata")
        $metadata.AppendChild($document.CreateAttribute("wcm:action", "add"))
    
        [XmlElement]$metadataKey = $document.CreateElement("Key")
        $metadataKey.InnerText = "/IMAGE/NAME"
        $metadata.AppendChild($metadataKey)

        [XmlElement]$metadataValue = $document.CreateElement("Value")
        $metadataValue.InnerText = "" # FIXME: Get this value from $Machine
        $metadata.AppendChild($metadataValue)

        $installFrom.AppendChild($metadata)

        $osImage.AppendChild($installFrom)

        $imageInstall.AppendChild($osImage)

        return $imageInstall
    }

    [XmlElement]GenerateAutoUnattendWinpeSettingsInternationalizationComponent([XmlDocument]$document)
    {
        [XmlElement]$component = $document.CreateElement("component")
        $component.AppendChild($document.CreateAttribute("xmlns:wcm", "http://schemas.microsoft.com/WMIConfig/2002/State"))
        $component.AppendChild($document.CreateAttribute("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance"))
        $component.AppendChild($document.CreateAttribute("name", "Microsoft-Windows-International-Core-WinPE"))
        $component.AppendChild($document.CreateAttribute("processorArchitecture", "amd64"))
        $component.AppendChild($document.CreateAttribute("publicKeyToken", "31bf3856ad364e35"))
        $component.AppendChild($document.CreateAttribute("language", "neutral"))
        $component.AppendChild($document.CreateAttribute("versionScope", "nonSxS"))
    
        [XmlElement]$setupUILanguage = $document.CreateElement("SetupUILanguage")
    
        # TODO: Make Language/Locale configurable via script input parameters

        [XmlElement]$setupUILanguageUILanguage = $document.CreateElement("UILanguage")
        $setupUILanguageUILanguage.InnerText = "en-US"
        $setupUILanguage.AppendChild($setupUILanguageUILanguage)
    
        $component.AppendChild($setupUILanguage)

        [XmlElement]$inputLocale = $document.CreateElement("InputLocale")
        $inputLocale.InnerText = "en-US"
        $component.AppendChild($inputLocale)
    
        [XmlElement]$systemLocale = $document.CreateElement("SystemLocale")
        $systemLocale.InnerText = "en-US"
        $component.AppendChild($systemLocale)
    
        [XmlElement]$uiLanguage = $document.CreateElement("UILanguage")
        $uiLanguage.InnerText = "en-US"
        $component.AppendChild($uiLanguage)
    
        [XmlElement]$uiLanguageFallback = $document.CreateElement("UILanguageFallback")
        $uiLanguageFallback.InnerText = "en-US"
        $component.AppendChild($uiLanguageFallback)
    
        [XmlElement]$userLocale = $document.CreateElement("UserLocale")
        $userLocale.InnerText = "en-US"
        $component.AppendChild($userLocale)

        return $component
    }

    [XmlElement]GenerateAutoUnattendOfflineServicingSettings([XmlDocument]$document)
    {
        [XmlElement]$settings = $document.CreateElement("settings")
        $settings.SetAttribute("pass", "offlineServicing")
    
        [XmlElement]$luaSettingsComponent = $document.CreateElement("component")
        $luaSettingsComponent.AppendChild($document.CreateAttribute("name", "Microsoft-Windows-LUA-Settings"))
        $luaSettingsComponent.AppendChild($document.CreateAttribute("processorArchitecture", "amd64"))
        $luaSettingsComponent.AppendChild($document.CreateAttribute("publicKeyToken", "31bf3856ad364e35"))
        $luaSettingsComponent.AppendChild($document.CreateAttribute("language", "neutral"))
        $luaSettingsComponent.AppendChild($document.CreateAttribute("versionScope", "nonSxS"))

        [XmlElement]$enableLua = $document.CreateElement("EnableLUA")
        $enableLua.InnerText = "false"
        $luaSettingsComponent.AppendChild($enableLua)

        $settings.AppendChild($luaSettingsComponent)

        return $settings
    }

    [XmlElement]GenerateAutoUnattendOobeSystemSettings([XmlDocument]$document)
    {
        [XmlElement]$settings = $document.CreateElement("settings")
        $settings.SetAttribute("pass", "oobeSystem")
    
        [XmlElement]$shellSetupComponent = $this.GenerateAutoUnattendOobeSystemSettingsShellSetupComponent($document)

        $settings.AppendChild($shellSetupComponent)

        return $settings
    }

    [XmlElement]GenerateAutoUnattendOobeSystemSettingsShellSetupComponent([XmlDocument]$document)
    {
        [XmlElement]$component = $document.CreateElement("component")
        $component.AppendChild($document.CreateAttribute("xmlns:wcm", "http://schemas.microsoft.com/WMIConfig/2002/State"))
        $component.AppendChild($document.CreateAttribute("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance"))
        $component.AppendChild($document.CreateAttribute("name", "Microsoft-Windows-Shell-Setup"))
        $component.AppendChild($document.CreateAttribute("processorArchitecture", "amd64"))
        $component.AppendChild($document.CreateAttribute("publicKeyToken", "31bf3856ad364e35"))
        $component.AppendChild($document.CreateAttribute("language", "neutral"))
        $component.AppendChild($document.CreateAttribute("versionScope", "nonSxS"))

        [XmlElement]$userAccounts = $this.GenerateAutoUnattendOobeSystemSettingsShellSetupComponentUserAccounts($document)
        $component.AppendChild($userAccounts)

        [XmlElement]$oobe = $this.GenerateAutoUnattendOobeSystemSettingsShellSetupComponentUserAccounts($document)
        $component.AppendChild($oobe)

        [XmlElement]$autoLogon = $this.GenerateAutoUnattendOobeSystemSettingsShellSetupComponentAutoLogon($document)
        $component.AppendChild($autoLogon)

        [XmlElement]$firstLogonCommands = $this.GenerateAutoUnattendOobeSystemSettingsShellSetupComponentFirstLogonCommands($document)
        $component.AppendChild($firstLogonCommands)

        [XmlElement]$showWindowsLive = $document.CreateElement("ShowWindowsLive")
        $showWindowsLive.InnerText = "false"
        $component.AppendChild($showWindowsLive)

        return $component
    }

    [XmlElement]GenerateAutoUnattendOobeSystemSettingsShellSetupComponentUserAccounts([XmlDocument]$document)
    {
        [XmlElement]$userAccounts = $document.CreateElement("UserAccounts")

        [XmlElement]$administratorPassword = $document.CreateElement("AdministratorPassword")

        [XmlElement]$administratorPasswordValue = $document.CreateElement("Value")
        $administratorPasswordValue.InnerText = $this.WinrmPassword
        $administratorPassword.AppendChild($administratorPasswordValue)

        [XmlElement]$administratorPasswordPlainText = $document.CreateElement("Value")
        $administratorPasswordPlainText.InnerText = "true"
        $administratorPassword.AppendChild($administratorPasswordPlainText)

        $userAccounts.AppendChild($administratorPassword)

        [XmlElement]$localAccounts = $document.CreateElement("LocalAccounts")

        [XmlElement]$localAccountVagrant = $document.CreateElement("LocalAccount")
    
        $localAccountVagrant.AppendChild($document.CreateAttribute("wcm:action", "add"))

        [XmlElement]$localAccountVagrantPassword = $document.CreateElement("Password")

        [XmlElement]$localAccountVagrantPasswordValue = $document.CreateElement("Value")
        $localAccountVagrantPasswordValue.InnerText = $this.WinrmPassword
        $localAccountVagrantPassword.AppendChild($localAccountVagrantPasswordValue)

        [XmlElement]$localAccountVagrantPasswordPlainText = $document.CreateElement("PlainText")
        $localAccountVagrantPasswordPlainText.InnerText = "true"
        $localAccountVagrantPassword.AppendChild($localAccountVagrantPasswordPlainText)

        $localAccountVagrant.AppendChild($localAccountVagrantPassword)

        [XmlElement]$localAccountVagrantDescription = $document.CreateElement("Description")
        $localAccountVagrantDescription.InnerText = "Vagrant User"
        $localAccountVagrant.AppendChild($localAccountVagrantDescription)

        [XmlElement]$localAccountVagrantDisplayName = $document.CreateElement("DisplayName")
        $localAccountVagrantDisplayName.InnerText = $this.WinrmUsername
        $localAccountVagrant.AppendChild($localAccountVagrantDisplayName)

        [XmlElement]$localAccountVagrantGroup = $document.CreateElement("Group")
        $localAccountVagrantGroup.InnerText = "administrators"
        $localAccountVagrant.AppendChild($localAccountVagrantGroup)

        [XmlElement]$localAccountVagrantName = $document.CreateElement("Name")
        $localAccountVagrantName.InnerText = $this.WinrmUsername
        $localAccountVagrant.AppendChild($localAccountVagrantName)
    
        $localAccounts.AppendChild($localAccountVagrant)

        $userAccounts.AppendChild($localAccounts)

        return $userAccounts
    }

    [XmlElement]GenerateAutoUnattendOobeSystemSettingsShellSetupComponentOobe([XmlDocument]$document)
    {
        [XmlElement]$oobe = $document.CreateElement("OOBE")

        [XmlElement]$hideEulaPage = $document.CreateElement("HideEULAPage")
        $hideEulaPage.InnerText = "true"
        $oobe.AppendChild($hideEulaPage)

        [XmlElement]$hideWirelessSetupInOobe = $document.CreateElement("HideWirelessSetupInOOBE")
        $hideWirelessSetupInOobe.InnerText = "true"
        $oobe.AppendChild($hideWirelessSetupInOobe)

        [XmlElement]$networkLocation = $document.CreateElement("NetworkLocation")
        $networkLocation.InnerText = "Home"
        $oobe.AppendChild($networkLocation)

        [XmlElement]$protectYourPc = $document.CreateElement("ProtectYourPC")
        $protectYourPc.InnerText = "1"
        $oobe.AppendChild($protectYourPc)

        return $oobe
    }

    [XmlElement]GenerateAutoUnattendOobeSystemSettingsShellSetupComponentAutoLogon([XmlDocument]$document)
    {
        [XmlElement]$autoLogon = $document.CreateElement("AutoLogon")

        [XmlElement]$autoLogonPassword = $document.CreateElement("Password")

        [XmlElement]$autoLogonPasswordValue = $document.CreateElement("Value")
        $autoLogonPasswordValue.InnerText = $this.WinrmPassword
        $autoLogonPassword.AppendChild($autoLogonPasswordValue)

        [XmlElement]$autoLogonPasswordPlainText = $document.CreateElement("PlainText")
        $autoLogonPasswordPlainText.InnerText = "true"
        $autoLogonPassword.AppendChild($autoLogonPasswordPlainText)

        $autoLogon.AppendChild($autoLogonPassword)

        [XmlElement]$autoLogonUsername = $document.CreateElement("Username")
        $autoLogonUsername.InnerText = $this.WinrmUsername
        $autoLogon.AppendChild($autoLogonUsername)

        [XmlElement]$autoLogonEnabled = $document.CreateElement("Enabled")
        $autoLogonEnabled.InnerText = "true"
        $autoLogon.AppendChild($autoLogonEnabled)

        return $autoLogon
    }

    [XmlElement]GenerateAutoUnattendOobeSystemSettingsShellSetupComponentFirstLogonCommands([XmlDocument]$document)
    {
        [XmlElement]$firstLogonCommands = $document.CreateElement("FirstLogonCommands")

        foreach ($command in $this.SetupCommands)
        {
            [XmlElement]$synchronousCommand = $document.CreateElement("SynchronousCommand")
        
            $synchronousCommand.AppendChild($document.CreateAttribute("wcm:action", "add"))

            [XmlElement]$commandLine = $document.CreateElement("CommandLine")
            $commandLine.InnerText = $command.Command
            $synchronousCommand.AppendChild($commandLine)

            [XmlElement]$description = $document.CreateElement("Description")
            $description.InnerText = $command.Description
            $synchronousCommand.AppendChild($description)

            [XmlElement]$order = $document.CreateElement("order")
            $order.InnerText = ("{0}" -f $this.SetupCommands.IndexOf($command))
            $synchronousCommand.AppendChild($order)

            if ($command.RequiresUserInput)
            {
                [XmlElement]$requiresUserInput = $document.CreateElement("requiresUserInput")
                $requiresUserInput.InnerText = "true"
                $synchronousCommand.AppendChild($requiresUserInput)
            }

            $firstLogonCommands.AppendChild($synchronousCommand)
        }

        return $firstLogonCommands
    }

    [XmlElement]GenerateAutoUnattendSpecializeSettings([XmlDocument]$document)
    {
        [XmlElement]$settings = $document.CreateElement("settings")
        $settings.SetAttribute("pass", "specialize")

        [XmlElement]$setupComponent = $document.CreateElement("component")
        $setupComponent.AppendChild($document.CreateAttribute("name", "Microsoft-Windows-Shell-Setup"))
        $setupComponent.AppendChild($document.CreateAttribute("processorArchitecture", "amd64"))
        $setupComponent.AppendChild($document.CreateAttribute("publicKeyToken", "31bf3856ad364e35"))
        $setupComponent.AppendChild($document.CreateAttribute("language", "neutral"))
        $setupComponent.AppendChild($document.CreateAttribute("versionScope", "nonSxS"))

        [XmlElement]$oemInformation = $document.CreateElement("OEMInformation")

        [XmlElement]$helpCustomized = $document.CreateElement("HelpCustomized")
        $helpCustomized.InnerText = "false"
        $oemInformation.AppendChild($helpCustomized)

        $setupComponent.AppendChild($oemInformation)

        [XmlElement]$computerName = $document.CreateElement("ComputerName")
        $computerName.InnerText = "" # FIXME: Generate computer name template.
        $setupComponent.AppendChild($computerName)

        # TODO: Make timezone configurable from script parameters if possible
        [XmlElement]$timeZone = $document.CreateElement("TimeZone")
        $timeZone.InnerText = "Pacific Standard Time"
        $setupComponent.AppendChild($timeZone)

        [XmlElement]$registeredOwner = $document.CreateElement("RegisteredOwner")
        $setupComponent.AppendChild($registeredOwner)

        $settings.AppendChild($setupComponent)
    
        [XmlElement]$securityComponent = $document.CreateElement("component")
        $securityComponent.AppendChild($document.CreateAttribute("xmlns:wcm", "http://schemas.microsoft.com/WMIConfig/2002/State"))
        $securityComponent.AppendChild($document.CreateAttribute("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance"))
        $securityComponent.AppendChild($document.CreateAttribute("name", "Microsoft-Windows-Security-SPP-UX"))
        $securityComponent.AppendChild($document.CreateAttribute("processorArchitecture", "amd64"))
        $securityComponent.AppendChild($document.CreateAttribute("publicKeyToken", "31bf3856ad364e35"))
        $securityComponent.AppendChild($document.CreateAttribute("language", "neutral"))
        $securityComponent.AppendChild($document.CreateAttribute("versionScope", "nonSxS"))

        [XmlElement]$skipAutoActivation = $document.CreateElement("SkipAutoActivation")
        $skipAutoActivation.InnerText = "true"
        $securityComponent.AppendChild($skipAutoActivation)

        $settings.AppendChild($securityComponent)

        return $settings
    }
    
}
