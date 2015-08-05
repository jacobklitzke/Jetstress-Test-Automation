Function Main
{   
    Get-Location
    DO
    {
        Write-Host 'This powershell script will automatically run Jetstress test(s), as well as determine whether or not those tests passed.'
        Write-Host 'To begin, please enter the number corresponding to the test(s) you wish to run.'
        Write-Host "`t1. Performance, Backup, Soft Recovery, and Stress"
        Write-Host "`t2. Performance"
        Write-Host "`t3. Backup"
        Write-Host "`t4. Soft Recovery"
        Write-Host "`t5. Stress"

        [int]$testNumber = Read-Host "Enter the number of the test(s) you wish to run "

        if($testNumber -lt 1 -or $testNumber -gt 5)
        {
            Write-Host "You have entered an invalid number. Please enter a number between 1 and 5."
        }
    } While ($testNumber -lt 1 -or $testNumber -gt 5)

    [string]$testDescription = Read-Host "Please enter the test description "

    [int]$numVolumes = Read-Host "Enter the number of volumes used in the test "
    [int]$numDatabases = Read-Host "Enter the number of databases used in the test "
    checkIfDecimal

    [int] $mailboxes = Read-Host "Enter the number of mailboxes used in the test "
    [int] $mailboxSize = Read-Host "Enter the size in MB of each mailbox "
    [double]$IOPS = Read-Host "Enter the number of IOPS per User "
    [int]$threadCount = Read-Host "Enter the number of threads used in the test "

    [string[]]$volumePaths = getVolumePaths

    $createDatabases = Read-Host "Do you want to create new databases? Enter 1 for yes and 0 for no "
    if($createDatabases -eq 1)
    {
        createDatabaseFolders
    }
    #If you do not select to create databases, I will assume the folder structure is already correct. (e.g. \path\to\volume\DB1)


    Switch ($testNumber)
    {
        1 {allTests}
        2 {performanceTest}
        3 {backupTest}
        4 {recoveryTest}
        5 {stressTest}
    }
}

Function allTests
{
    performanceTest
    backupTest
    recoveryTest
    stressTest

}

Function performanceTest
{
    [int]$repeatTest = 0
    DO
    {
        New-Item -Path 'Performance Results' -ItemType directory

        [string]$xmlfile = 'JetstressConfig.xml'
        $xml = [xml](Get-Content $xmlfile)

        #Edit the type of test
        $xml.configuration.TestDesignInfo.Type = 'Performance'

        #Edit the description
        $xml.configuration.TestDesignInfo.Description = $testDescription

        #Edit the duration
        $xml.configuration.TestDesignInfo.Duration = 'P0Y0M0DT2H0M0S'

        #Edit the output path
        $xml.configuration.TestDesignInfo.OutputPath = '.\Performance Results'

        #Edit the thread count
        $xml.configuration.ExchangeProfile.ThreadCount = $threadCount.ToString()

        if($createDatabases -eq 0)
        {
            $xml.configuration.ExchangeProfile.DatabaseSource = 'Open'
        }
        else
        {
            $xml.configuration.ExchangeProfile.DatabaseSource = 'New'
        }

        #Edit the mailbox count
        $xml.configuration.ExchangeProfile.MailboxCount = $mailboxes.ToString()

        #Edit mailbox size
        $xml.configuration.ExchangeProfile.MailboxQuota = $mailboxSize.ToString()

        #Edit the IOPS
        $xml.configuration.ExchangeProfile.MailboxIops = $IOPS.ToString()

        #Edit the database paths
        $EseInstances = $xml.CreateElement("EseInstances")

        [int]$databasesPerVolume = $numDatabases/$numVolumes
        [int]$counter = 1
        [int]$reverseCounter = $numDatabases
        [int]$reverseVolumeCounter = $numVolumes - 1
        $EseInstances = $xml.CreateElement("EseInstances")

        for([int]$i = 0; $i -lt $numVolumes; $i++)
        {
            for([int]$j = 0; $j -lt $databasesPerVolume; $j++)
            {
                $EseInstance = $xml.CreateElement("EseInstance")
                $EseInstance.SetAttribute("IopsBias", "1")
                $DatabasePaths = $xml.CreateElement("DatabasePaths")
                $pathToDatabase = $xml.CreateElement("Path")
                $pathToLog = $xml.CreateElement("LogPath")
                $databaseBackupPath = $xml.CreateElement("DatabaseBackupPath")

                $volumePath = $volumePaths[$i]
                $volumePath += "\DB$counter"
                $pathToDatabase.AppendChild($xml.CreateTextNode("$($volumePath)"))

                $volumePath = $volumePaths[$reverseVolumeCounter]
                $volumePath += "\Log$Counter"
                $pathToLog.AppendChild($xml.CreateTextNode("$($volumePath)"))

                $DatabasePaths.AppendChild($pathToDatabase)
                $EseInstance.AppendChild($DatabasePaths)
                $EseInstance.AppendChild($pathToLog)
                $EseInstance.AppendChild($databaseBackupPath)
                $EseInstances.AppendChild($EseInstance)

                $counter++
                $reverseCounter--
            }
            $reverseVolumeCounter--
        }
    
        $xml.configuration.ExchangeProfile.AppendChild($EseInstances)
        $xml.Save('JetStressConfigPerformance.xml')

        ./JetstressCmd.exe /c JetstressConfigPerformance.xml

        if(-Not (select-string -Path '.\Performance Results\Performance*.html' -pattern "<td class=`"success`">Pass</td>" -Quiet))
        {
            Write-Host "This test has failed. Usually when tests fail, the thread count needs to be adjusted. Please review the test files and determine whether or not you would like to edit the thread count."
            Write-Host "Note: If you choose to adjust the thread count, the Performance testing directory will be removed. Please save your files elsewhere if you wish to keep them."
            [int]$threadAdjustment = Read-Host "Would you like to adjust the thread count? Enter 1 for yes and 0 for no "

            if($threadAdjustment -eq 1)
            {
                $threadCount = Read-Host "Enter the new thread count "
                $repeatTest = 1
                $createDatabases = 0
                Remove-Item -Recurse -Force '.\Performance Testing'
            }
            else
            {
                Write-Host "Nothing to do. Goodbye!"
                $repeatTest = 0
            }
        }
        else
        {
            Write-Host "Test completed and passed!"
            $repeatTest = 0
        }
    }While ($repeatTest -eq 1)

    Read-Host "timeout"
}

Function backupTest
{
    [int]$repeatTest = 0
    DO
    {
        New-Item -Path 'Backup Results' -ItemType directory

        [string]$xmlfile = 'JetstressConfig.xml'
        $xml = [xml](Get-Content $xmlfile)

        #Edit the type of test
        $xml.configuration.TestDesignInfo.Type = 'DatabaseBackup'

        #Edit the description
        $xml.configuration.TestDesignInfo.Description = $testDescription

        #Edit the duration
        $xml.configuration.TestDesignInfo.Duration = 'P0Y0M0DT2H0M0S'

        #Edit the output path
        $xml.configuration.TestDesignInfo.OutputPath = '.\Backup Results'

        #Edit the thread count
        $xml.configuration.ExchangeProfile.ThreadCount = $threadCount.ToString()

        if($createDatabases -eq 0)
        {
            $xml.configuration.ExchangeProfile.DatabaseSource = 'Open'
        }
        else
        {
            $xml.configuration.ExchangeProfile.DatabaseSource = 'New'
        }

        #Edit the mailbox count
        $xml.configuration.ExchangeProfile.MailboxCount = $mailboxes.ToString()

        #Edit mailbox size
        $xml.configuration.ExchangeProfile.MailboxQuota = $mailboxSize.ToString()

        #Edit the IOPS
        $xml.configuration.ExchangeProfile.MailboxIops = $IOPS.ToString()

        #Edit the database paths
        $EseInstances = $xml.CreateElement("EseInstances")

        [int]$databasesPerVolume = $numDatabases/$numVolumes
        [int]$counter = 1
        [int]$reverseCounter = $numDatabases
        [int]$reverseVolumeCounter = $numVolumes - 1
        $EseInstances = $xml.CreateElement("EseInstances")

        for([int]$i = 0; $i -lt $numVolumes; $i++)
        {
            for([int]$j = 0; $j -lt $databasesPerVolume; $j++)
            {
                $EseInstance = $xml.CreateElement("EseInstance")
                $EseInstance.SetAttribute("IopsBias", "1")
                $DatabasePaths = $xml.CreateElement("DatabasePaths")
                $pathToDatabase = $xml.CreateElement("Path")
                $pathToLog = $xml.CreateElement("LogPath")
                $databaseBackupPath = $xml.CreateElement("DatabaseBackupPath")

                $volumePath = $volumePaths[$i]
                $volumePath += "\DB$counter"
                $pathToDatabase.AppendChild($xml.CreateTextNode("$($volumePath)"))

                $volumePath = $volumePaths[$reverseVolumeCounter]
                $volumePath += "\Log$Counter"
                $pathToLog.AppendChild($xml.CreateTextNode("$($volumePath)"))

                $DatabasePaths.AppendChild($pathToDatabase)
                $EseInstance.AppendChild($DatabasePaths)
                $EseInstance.AppendChild($pathToLog)
                $EseInstance.AppendChild($databaseBackupPath)
                $EseInstances.AppendChild($EseInstance)

                $counter++
                $reverseCounter--
            }
            $reverseVolumeCounter--
        }
    
        $xml.configuration.ExchangeProfile.AppendChild($EseInstances)
        $xml.Save('JetStressConfigBackup.xml')

        ./JetstressCmd.exe /c JetstressConfigBackup.xml

        Write-Host "Test completed and passed!"
        $repeatTest = 0
      
    }While ($repeatTest -eq 1)
}

Function recoveryTest
{
    [int]$repeatTest = 0
    DO
    {
        New-Item -Path 'Soft Recovery Results' -ItemType directory

        [string]$xmlfile = 'JetstressConfig.xml'
        $xml = [xml](Get-Content $xmlfile)

        #Edit the type of test
        $xml.configuration.TestDesignInfo.Type = 'SoftRecovery'

        #Edit the description
        $xml.configuration.TestDesignInfo.Description = $testDescription

        #Edit the duration
        $xml.configuration.TestDesignInfo.Duration = 'P0Y0M0DT2H0M0S'

        #Edit the output path
        $xml.configuration.TestDesignInfo.OutputPath = '.\Soft Recovery Results'

        #Edit the thread count
        $xml.configuration.ExchangeProfile.ThreadCount = $threadCount.ToString()

        if($createDatabases -eq 0)
        {
            $xml.configuration.ExchangeProfile.DatabaseSource = 'Open'
        }
        else
        {
            $xml.configuration.ExchangeProfile.DatabaseSource = 'New'
        }

        #Edit the mailbox count
        $xml.configuration.ExchangeProfile.MailboxCount = $mailboxes.ToString()

        #Edit mailbox size
        $xml.configuration.ExchangeProfile.MailboxQuota = $mailboxSize.ToString()

        #Edit the IOPS
        $xml.configuration.ExchangeProfile.MailboxIops = $IOPS.ToString()

        #Edit the database paths
        $EseInstances = $xml.CreateElement("EseInstances")

        [int]$databasesPerVolume = $numDatabases/$numVolumes
        [int]$counter = 1
        [int]$reverseCounter = $numDatabases
        [int]$reverseVolumeCounter = $numVolumes - 1
        $EseInstances = $xml.CreateElement("EseInstances")

        for([int]$i = 0; $i -lt $numVolumes; $i++)
        {
            for([int]$j = 0; $j -lt $databasesPerVolume; $j++)
            {
                $EseInstance = $xml.CreateElement("EseInstance")
                $EseInstance.SetAttribute("IopsBias", "1")
                $DatabasePaths = $xml.CreateElement("DatabasePaths")
                $pathToDatabase = $xml.CreateElement("Path")
                $pathToLog = $xml.CreateElement("LogPath")
                $databaseBackupPath = $xml.CreateElement("DatabaseBackupPath")

                $volumePath = $volumePaths[$i]
                $volumePath += "\DB$counter"
                $pathToDatabase.AppendChild($xml.CreateTextNode("$($volumePath)"))

                $volumePath = $volumePaths[$reverseVolumeCounter]
                $volumePath += "\Log$Counter"
                $pathToLog.AppendChild($xml.CreateTextNode("$($volumePath)"))

                $DatabasePaths.AppendChild($pathToDatabase)
                $EseInstance.AppendChild($DatabasePaths)
                $EseInstance.AppendChild($pathToLog)
                $EseInstance.AppendChild($databaseBackupPath)
                $EseInstances.AppendChild($EseInstance)

                $counter++
                $reverseCounter--
            }
            $reverseVolumeCounter--
        }
    
        $xml.configuration.ExchangeProfile.AppendChild($EseInstances)
        $xml.Save('JetStressConfigRecovery.xml')

        ./JetstressCmd.exe /c JetstressConfigRecovery.xml

        Write-Host "Test completed and passed!"
        $repeatTest = 0
      
    }While ($repeatTest -eq 1)
}

Function stressTest
{
    [int]$repeatTest = 0
    DO
    {
        New-Item -Path 'Stress Results' -ItemType directory

        [string]$xmlfile = 'JetstressConfig.xml'
        $xml = [xml](Get-Content $xmlfile)

        #Edit the type of test
        $xml.configuration.TestDesignInfo.Type = 'Stress'

        #Edit the description
        $xml.configuration.TestDesignInfo.Description = $testDescription

        #Edit the duration
        $xml.configuration.TestDesignInfo.Duration = 'P0Y0M1DT0H0M0S'

        #Edit the output path
        $xml.configuration.TestDesignInfo.OutputPath = '.\Stress Results'

        #Edit the thread count
        $xml.configuration.ExchangeProfile.ThreadCount = $threadCount.ToString()

        if($createDatabases -eq 0)
        {
            $xml.configuration.ExchangeProfile.DatabaseSource = 'Open'
        }
        else
        {
            $xml.configuration.ExchangeProfile.DatabaseSource = 'New'
        }

        #Edit the mailbox count
        $xml.configuration.ExchangeProfile.MailboxCount = $mailboxes.ToString()

        #Edit mailbox size
        $xml.configuration.ExchangeProfile.MailboxQuota = $mailboxSize.ToString()

        #Edit the IOPS
        $xml.configuration.ExchangeProfile.MailboxIops = $IOPS.ToString()

        #Edit the database paths
        $EseInstances = $xml.CreateElement("EseInstances")

        [int]$databasesPerVolume = $numDatabases/$numVolumes
        [int]$counter = 1
        [int]$reverseCounter = $numDatabases
        [int]$reverseVolumeCounter = $numVolumes - 1
        $EseInstances = $xml.CreateElement("EseInstances")

        for([int]$i = 0; $i -lt $numVolumes; $i++)
        {
            for([int]$j = 0; $j -lt $databasesPerVolume; $j++)
            {
                $EseInstance = $xml.CreateElement("EseInstance")
                $EseInstance.SetAttribute("IopsBias", "1")
                $DatabasePaths = $xml.CreateElement("DatabasePaths")
                $pathToDatabase = $xml.CreateElement("Path")
                $pathToLog = $xml.CreateElement("LogPath")
                $databaseBackupPath = $xml.CreateElement("DatabaseBackupPath")

                $volumePath = $volumePaths[$i]
                $volumePath += "\DB$counter"
                $pathToDatabase.AppendChild($xml.CreateTextNode("$($volumePath)"))

                $volumePath = $volumePaths[$reverseVolumeCounter]
                $volumePath += "\Log$Counter"
                $pathToLog.AppendChild($xml.CreateTextNode("$($volumePath)"))

                $DatabasePaths.AppendChild($pathToDatabase)
                $EseInstance.AppendChild($DatabasePaths)
                $EseInstance.AppendChild($pathToLog)
                $EseInstance.AppendChild($databaseBackupPath)
                $EseInstances.AppendChild($EseInstance)

                $counter++
                $reverseCounter--
            }
            $reverseVolumeCounter--
        }
    
        $xml.configuration.ExchangeProfile.AppendChild($EseInstances)
        $xml.Save('JetStressConfigStress.xml')

        ./JetstressCmd.exe /c JetstressConfigStress.xml

        if(-Not (select-string -Path '.\Stress Results\Stress*.html' -pattern "<td class=`"success`">Pass</td>" -Quiet))
        {
            Write-Host "This test has failed. Usually when tests fail, the thread count needs to be adjusted. Please review the test files and determine whether or not you would like to edit the thread count."
            Write-Host "Note: If you choose to adjust the thread count, the Performance testing directory will be removed. Please save your files elsewhere if you wish to keep them."
            [int]$threadAdjustment = Read-Host "Would you like to adjust the thread count? Enter 1 for yes and 0 for no "

            if($threadAdjustment -eq 1)
            {
                $threadCount = Read-Host "Enter the new thread count "
                $repeatTest = 1
                $createDatabases = 0
                Remove-Item -Recurse -Force '.\Stress Testing'
            }
            else
            {
                Write-Host "Nothing to do. Goodbye!"
                $repeatTest = 0
            }
        }
        else
        {
            Write-Host "Test completed and passed!"
            $repeatTest = 0
        }
    }While ($repeatTest -eq 1)
    #Edit the type of test
    $xml.configuration.TestDesignInfo.Type = 'Stress'

}

Function checkIfDecimal
{
    $double = $numDatabases/$numVolumes
    if($double.GetType() -eq [System.double])
    {
        Write-Host "Error. The program cannot proceed because it cannot evenly distribute the databases between the volumes. Please check you volumes and database inputs."
        Exit
    }

}

Function getVolumePaths
{
    [string[]]$volumePaths = @()
    for([int]$i = 0; $i -lt $numVolumes; $i++)
    {
        $volumePaths += Read-Host "Enter the path for Volume $($i + 1) "
        if($volumePaths[$i].StartsWith("`""))
        {
            $volumePaths[$i] = $volumePaths[$i].Substring(1, $volumePaths[$i].Length -1 )
        }
        if($volumePaths[$i].EndsWith("`""))
        {
            $volumePaths[$i] = $volumePaths[$i].Substring(0, $volumePaths[$i].Length - 1)
        }
        if($volumePaths[$i].EndsWith("`\"))
        {
            $volumePaths[$i] = $volumePaths[$i].Substring(0, $volumePaths[$i].Length - 1)
        }
    }
    return $volumePaths
    
}

Function createDatabaseFolders
{
    [int]$databasesPerVolume = $numDatabases/$numVolumes
    [int]$counter = 1
    [int]$reverseCounter = $numDatabases
    for([int]$i = 0; $i -lt $numVolumes; $i++)
    {
        for([int]$j = 0; $j -lt $databasesPerVolume; $j++)
        {
            $volumePath = $volumePaths[$i]

            $volumePath += "\DB$counter"
            New-Item -Path $volumePath -ItemType directory

            $volumePath = $volumePaths[$i]

            $volumePath += "\Log$reverseCounter"
            New-Item -Path $volumePath -ItemType directory
            $counter++
            $reverseCounter--
        }
    }

}

Function xmlEdit
{
    
}

Main
