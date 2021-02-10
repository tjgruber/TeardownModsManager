<# Teardown Mods Manager v2.1.0 | by Timothy Gruber

Designed and written by Timothy Gruber:
    https://timothygruber.com
    https://github.com/tjgruber/TeardownModsManager

#>

#region Run script as elevated admin and unrestricted executionpolicy
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID)
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
if ($myWindowsPrincipal.IsInRole($adminRole)) {
    $Host.UI.RawUI.WindowTitle = "Teardown Mods Manager v2.1.0 | by Timothy Gruber"
    $Host.UI.RawUI.BackgroundColor = "DarkBlue"
    Clear-Host
} else {
    Start-Process PowerShell.exe -ArgumentList "-ExecutionPolicy Unrestricted -NoExit $($script:MyInvocation.MyCommand.Path)" -Verb RunAs
    Exit
}
#endregion

Write-Host "Running Teardown Mods Manager v2.1.0 | by Timothy Gruber...`n`nClosing this window will close Teardown Mods Manager.`n"

#  ███    ███  █████  ██ ███    ██     ██     ██ ██ ███    ██ ██████   ██████  ██     ██ 
#  ████  ████ ██   ██ ██ ████   ██     ██     ██ ██ ████   ██ ██   ██ ██    ██ ██     ██ 
#  ██ ████ ██ ███████ ██ ██ ██  ██     ██  █  ██ ██ ██ ██  ██ ██   ██ ██    ██ ██  █  ██ 
#  ██  ██  ██ ██   ██ ██ ██  ██ ██     ██ ███ ██ ██ ██  ██ ██ ██   ██ ██    ██ ██ ███ ██ 
#  ██      ██ ██   ██ ██ ██   ████      ███ ███  ██ ██   ████ ██████   ██████   ███ ███  

#region MAIN WINDOW
$syncHash = [hashtable]::Synchronized(@{})
$manWindowRunspace = [runspacefactory]::CreateRunspace()
$manWindowRunspace.Name = "MainWindow"
$manWindowRunspace.ApartmentState = "STA"
$manWindowRunspace.ThreadOptions = "ReuseThread"
$manWindowRunspace.Open()
$manWindowRunspace.SessionStateProxy.SetVariable("syncHash", $syncHash)
$manWindowRunspaceScript = [PowerShell]::Create().AddScript({

    Add-Type -AssemblyName PresentationCore,PresentationFramework

    #############################################
    #############################################
    #region FUNCTIONS
    #############################################
    #############################################

    function Write-Log {
        [CmdletBinding()]
        Param (
            [Parameter(ValueFromPipeline=$true,Mandatory,Position=0)]
            [string]$Message,
            [switch]$ClearLog,
            [switch]$WriteOut
        )
    
        begin {
            if (($ClearLog) -or ($syncHash.tmmLog -notmatch "Log initialized:")) {
                $syncHash.tmmLog = @"

Log initialized: $(Get-Date)

"@
            }
        }
    
        process {
            $timestamp = "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')"
            $logText = "[$timestamp]`t$Message"
            $syncHash.tmmLog += "`n$logText"
        }
    
        end {
            if ($WriteOut) {
                Write-Output -InputObject $syncHash.tmmLog
            }
        }
    
    }

    Function Update-Window {
        Param (
            $Control,
            $Property,
            $Value,
            [switch]$AppendContent
        )
        If ($Property -eq "Close") {
            $syncHash.Window.Dispatcher.invoke([action]{$syncHash.Window.Close()},"Normal")
            Return
        }
        $syncHash.$Control.Dispatcher.Invoke([action]{
            If ($PSBoundParameters['AppendContent']) {
                $syncHash.$Control.AppendText($Value)
            } Else {
                $syncHash.$Control.$Property = $Value
            }
        }, "Normal")

        if ($Control -eq 'StatusBarText' -and $Property -eq 'Text') {
            Write-Log -Message $Value
        }

    }

    function Invoke-TablePrep {
        $columns = @(
        'ModName'
        'ModVersion'
        'ModAuthor'
        'ModDescription'
        'ModPath'
        'ModWebpage'
        'ModDownloadLink'
        )

        $syncHash.dataTable = New-Object System.Data.DataTable
        $syncHash.dataTable.Columns.AddRange($columns)

        $syncHash.headerRow = $syncHash.dataTable.NewRow()

        $syncHash.headerRow.ModName            = 'Mod Name'
        $syncHash.headerRow.ModVersion         = 'Mod Version'
        $syncHash.headerRow.ModAuthor          = 'Mod Author'
        $syncHash.headerRow.ModDescription     = 'Mod Description'
        $syncHash.headerRow.ModPath            = 'Mod Path'
        $syncHash.headerRow.ModWebpage         = 'Mod Webpage'
        $syncHash.headerRow.ModDownloadLink    = 'Mod Download Link'

        $syncHash.dataTable.Rows.Add($syncHash.headerRow)

        $syncHash.ModsListDataGrid.ItemsSource = $syncHash.dataTable.DefaultView

        $syncHash.ModsListDataGrid.IsReadOnly = $True
        $syncHash.ModsListDataGrid.CanUserAddRows = $False
        $syncHash.ModsListDataGrid.Visibility = "Visible"
    }

    function Get-ModDeets {
        [CmdletBinding()]
        param (
            [String]$ModDir,
            [Switch]$Single
        )
        "Running Get-ModDeets function" | Write-Log

        if (-not $ModDir) {
            if ($true -eq (Test-Path -Path "$env:USERPROFILE\Documents\Teardown\mods" -PathType Container)) {
                $ModDir = "$env:USERPROFILE\Documents\Teardown\mods"
                $allMods = Get-ChildItem -Path $modDir -Directory
            }
        } else {
            "ModDir is [$ModDir]" | Write-Log
            if ($true -eq (Test-Path -Path $ModDir -PathType Container)) {
                "ModDir [$ModDir] tests good" | Write-Log
                if ($Single) {
                    $allMods = Get-Item -Path $modDir
                } else {
                    $allMods = Get-ChildItem -Path $modDir -Directory
                }
            } else {"ERROR: ModDir [$ModDir] test failed." | Write-Log}
        }

        $crestaNameFilter = "500 Magnum|AC130 Airstrike|AK-47|AWP|Black Hole|Charge Shotgun|Desert Eagle|Dragonslayer|Dual Berettas|Dual Miniguns|Exploding Star|Guided Missile|Hadouken|Holy Grenade|Laser Cutter|Lightkatana|M4A1|M249|MGL|Minigun|Mjolner|Nova|P90|RPG|SCAR-20|Scorpion|SG-553"
        $crestaAuthorFilter = "My Cresta"
        $crestaMods = foreach ($mod in $allMods | Where-Object {$_.Name -match $crestaNameFilter}) {
            $modInfo = Get-Content -Path "$($mod.Fullname)\info.txt"
            $modAuthor = if (($modInfo -match 'author = ' -split 'author = ')[1].Length -gt 2) {($modInfo -match 'author = ' -split 'author = ')[1]} else {"modAuthor not found"}
            if ($modAuthor -eq $crestaAuthorFilter) {
                $mod
            }
        }
        $crestaMod = $crestaMods | Select-Object -First 1

        $allModsDeets = foreach ($mod in $allMods) {
            $modInfo        = Get-Content -Path "$($mod.Fullname)\info.txt"
            $modName        = if (($modInfo -match 'name = ' -split 'name = ')[1].Length -gt 2) {($modInfo -match 'name = ' -split 'name = ')[1] -replace "_",' '} else {"name not found in mod info.txt"}
            $modVersion     = if (($modInfo -match 'version = ' -split 'version = ')[1].Length -gt 2) {($modInfo -match 'version = ' -split 'version = ')[1] -replace "_",' '} else {"version missing in mod info.txt"}
            $modAuthor      = if (($modInfo -match 'author = ' -split 'author = ')[1].Length -gt 2) {($modInfo -match 'author = ' -split 'author = ')[1]} else {"author not found in mod info.txt"}
            $modDescription = if (($modInfo -match 'description = ' -split 'description = ')[1].Length -gt 2) {($modInfo -match 'description = ' -split 'description = ')[1]} else {"description not found in mod info.txt"}
            # Valid mod check:
            if(($modInfo -match 'name = ' -split 'name = ')[1].Length -lt 2) {
                "WARNING: [$($mod.Fullname)] is not a valid mod." | Write-Log
                Continue
            }
            # MyCresta Check
                if (($modAuthor -eq "My Cresta") -and ($mod -ne $crestaMod)) {
                    Continue
                }
            #Write-Host "Processing mod: [$modName]"
            if (($modName -split " ").Count -eq 1) {
                $modSearchName = $modName -replace "'s",''
            } elseif (($modName -split " ").Count -eq 2) {
                $modSearchNameSplit = $modName -split " "
                $modSearchName = $modSearchNameSplit[0] + " " + $modSearchNameSplit[1] -replace "'s",''
            } else {
                $modSearchNameSplit = $modName -split " "
                $modSearchName = $modSearchNameSplit[0] + " " + $modSearchNameSplit[1] -replace "'s",''
            }
            if ($mod -eq $crestaMod) {
                $modSearchName = "Functional Weapon Pack"
                $modName = "Functional Weapon Pack"
                $modDescription = "28 Different Fully Working Weapons"
            }

            [PSCustomObject]@{
                'ModName'           = $modName
                'ModVersion'        = $modVersion
                'ModAuthor'         = $modAuthor
                'ModDescription'    = $modDescription
                'ModPath'           = $mod.Fullname
                'ModWebPage'        = if ($modWebLink.Length -gt 25) {$modWebLink} else {"NA"}
                'ModDownloadLink'   = if ($modPackageDownloadLink.Length -gt 25) {$modPackageDownloadLink} else {"NA"}
                'modSearchName'     = $modSearchName
            }
        
            $modInfo = $null
            $modName = $null
            $modVersion = $null
            $modAuthor = $null
            $modDescription = $null

        }

        "End Get-ModDeets function." | Write-Log
        Write-Output -InputObject $allModsDeets

    }

    #############################################
    #############################################
    #endRegion FUNCTIONS
    #############################################
    #############################################

    #############################################
    #############################################
    #region XML PREP
    #############################################
    #############################################

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Teardown Mods Manager v2.1.0 | by Timothy Gruber" Height="540" Width="1000" ScrollViewer.VerticalScrollBarVisibility="Disabled" MinWidth="966" MinHeight="500">
    <Grid>
        <DockPanel>
            <StatusBar DockPanel.Dock="Bottom">
                <StatusBar.ItemsPanel>
                    <ItemsPanelTemplate>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*" />
                                <ColumnDefinition Width="Auto" />
                                <ColumnDefinition Width="Auto" />
                                <ColumnDefinition Width="Auto" />
                                <ColumnDefinition Width="Auto" />
                            </Grid.ColumnDefinitions>
                        </Grid>
                    </ItemsPanelTemplate>
                </StatusBar.ItemsPanel>
                <StatusBarItem Margin="2,0,0,0">
                    <TextBlock Name="StatusBarText" Text="Ready..." />
                </StatusBarItem>
                <Separator Grid.Column="1" />
                <StatusBarItem Grid.Column="2" Margin="0,0,0,0" Foreground="Red">
                    <Button Name="ExportLogsButton" Content="Export Logs" MinWidth="80" />
                </StatusBarItem>
                <Separator Grid.Column="3" />
                <StatusBarItem Grid.Column="4" Margin="0,0,2,0">
                    <ProgressBar Name="ProgressBar" Value="0" Width="150" Height="16" />
                </StatusBarItem>
            </StatusBar>
            <TabControl>
                <TabItem Header="Installed Mods" HorizontalAlignment="Left" Height="30" VerticalAlignment="Top" TextOptions.TextFormattingMode="Display" Width="125">
                    <DockPanel Margin="0,5,0,0">
                        <Grid DockPanel.Dock="Bottom" Margin="5,1"/>
                        <DockPanel DockPanel.Dock="Right" Margin="0">
                            <DockPanel DockPanel.Dock="Top" Margin="0">
                                <Button DockPanel.Dock="Right" Name="BackupAllMods" Content="Backup All Mods" VerticalAlignment="Center" Height="30" Width="150" FontSize="14" Padding="10,1" Margin="5,0" HorizontalAlignment="Right" FontWeight="Bold"/>
                                <Button DockPanel.Dock="Right" Name="ReloadModList" Content="Reload Mod List" VerticalAlignment="Center" Height="30" Width="150" FontSize="14" Padding="10,1" Margin="5,0" HorizontalAlignment="Right" FontWeight="Bold"/>
                                <Button DockPanel.Dock="Right" Name="DeleteSelectedMod" Content="Delete Selected Mod" VerticalAlignment="Center" Height="30" Width="150" FontSize="12" Padding="10,1" Margin="5,0" HorizontalAlignment="Right" FontWeight="Bold" BorderThickness="2" BorderBrush="#FFAA1F1F" Foreground="#FF8D0000" Background="#FFFFF5B7"/>
                                <Button DockPanel.Dock="Left" Name="UpdateAllSelectedMods" Content="Update All Selected Mods" VerticalAlignment="Center" Height="30" Width="200" FontSize="14" Padding="10,1" Margin="5,0" HorizontalAlignment="Right" FontWeight="Bold"/>
                                <StackPanel DockPanel.Dock="Left" HorizontalAlignment="Left" Margin="0,0,5,0">
                                    <Label Content="Teardown mods folder:" VerticalAlignment="Top" Padding="5,0" Margin="5,0" FontWeight="Bold" MinWidth="150" Height="15"/>
                                    <TextBox Name="SelectDefaultModsLocation" VerticalAlignment="Center" Height="18" FontSize="12" Padding="0,0,5,0" Margin="5,0" HorizontalAlignment="Right" IsReadOnlyCaretVisible="True" IsReadOnly="True" ToolTip="Click to select your Teardown mods location if displayed default is incorrect." MinWidth="150"/>
                                </StackPanel>
                            </DockPanel>
                            <GroupBox Name="ModsListBoxGroupBox" Header="Installed Mods List" Margin="0,2,0,0">
                                <DataGrid DockPanel.Dock="Top" Name="ModsListDataGrid" HorizontalScrollBarVisibility="Visible" HeadersVisibility="None" Visibility="Hidden">
                                    <DataGrid.RowStyle>
                                        <Style TargetType="DataGridRow">
                                            <Style.Triggers>
                                                <DataTrigger Binding="{Binding 'ModName'}" Value="Mod Name">
                                                    <Setter Property="Background" Value="#F3F3F3" />
                                                    <Setter Property="FontWeight" Value="Medium" />
                                                </DataTrigger>
                                                <DataTrigger Binding="{Binding 'ModVersion'}" Value="Mod Version">
                                                    <Setter Property="Background" Value="#F3F3F3" />
                                                    <Setter Property="FontWeight" Value="Medium" />
                                                </DataTrigger>
                                                <DataTrigger Binding="{Binding 'ModAuthor'}" Value="Mod Author">
                                                    <Setter Property="Background" Value="#F3F3F3" />
                                                    <Setter Property="FontWeight" Value="Medium" />
                                                </DataTrigger>
                                                <DataTrigger Binding="{Binding 'ModDescription'}" Value="Mod Description">
                                                    <Setter Property="Background" Value="#F3F3F3" />
                                                    <Setter Property="FontWeight" Value="Medium" />
                                                </DataTrigger>
                                                <DataTrigger Binding="{Binding 'ModPath'}" Value="Mod Path">
                                                    <Setter Property="Background" Value="#F3F3F3" />
                                                    <Setter Property="FontWeight" Value="Medium" />
                                                </DataTrigger>
                                                <DataTrigger Binding="{Binding 'ModWebpage'}" Value="Mod Webpage">
                                                    <Setter Property="Background" Value="#F3F3F3" />
                                                    <Setter Property="FontWeight" Value="Medium" />
                                                </DataTrigger>
                                                <DataTrigger Binding="{Binding 'ModDownloadLink'}" Value="Mod Download Link">
                                                    <Setter Property="Background" Value="#F3F3F3" />
                                                    <Setter Property="FontWeight" Value="Medium" />
                                                </DataTrigger>
                                            </Style.Triggers>
                                        </Style>
                                    </DataGrid.RowStyle>
                                </DataGrid>
                            </GroupBox>
                        </DockPanel>
                    </DockPanel>
                </TabItem>
                <TabItem Header="Help" HorizontalAlignment="Left" Height="30" VerticalAlignment="Top" TextOptions.TextFormattingMode="Display" Width="100">
                    <DockPanel Margin="0,5,0,0">
                        <GroupBox Header="about" DockPanel.Dock="Bottom" VerticalAlignment="Bottom" FontWeight="Bold">
                            <ScrollViewer>
                                <TextBlock TextWrapping="Wrap" FontWeight="Normal"><Run FontWeight="Bold" Text="Created by: "/><Run Text="&#x9;Timothy Gruber&#xA;"/><Run FontWeight="Bold" Text="Website:&#x9;"/><Hyperlink NavigateUri="https://timothygruber.com/"><Run Text="TimothyGruber.com&#xA;"/></Hyperlink><Run FontWeight="Bold" Text="GitHub:&#x9;&#x9;"/><Hyperlink NavigateUri="https://github.com/tjgruber/TeardownModsManager"><Run Text="https://github.com/tjgruber/TeardownModsManager&#xA;"/></Hyperlink><Run FontWeight="Bold" Text="Version:"/><Run Text="&#x9;&#x9;v2.1.0"/></TextBlock>
                            </ScrollViewer>
                        </GroupBox>
                        <GroupBox Header="Help Menu:" FontWeight="Bold" FontSize="14">
                            <TabControl TabStripPlacement="Left">
                                <TabItem Header="General" Height="35" TextOptions.TextFormattingMode="Display" VerticalAlignment="Top" HorizontalContentAlignment="Stretch" FontSize="14">
                                    <GroupBox Header="General..." FontSize="16">
                                        <ScrollViewer>
                                            <RichTextBox IsReadOnlyCaretVisible="True" IsReadOnly="True">
                                                <FlowDocument>
                                                    <Paragraph FontWeight="Normal" FontSize="14">
                                                        <Run FontWeight="Bold" Text="Teardown Mods Manager"/>
                                                        <Run Text=" may be used to update, backup, and remove installed Teardown mods during the wait for Steam Workshop availability in Teardown 0.6, and possibly after."/>
                                                    </Paragraph>
                                                    <Paragraph FontWeight="Normal" FontSize="14">
                                                        <Run Text="Now fully functional, but still a work in progress, at least until Steam Workshop implementation in Teardown 0.6 potentially makes this obsolete."/>
                                                    </Paragraph>
                                                    <Paragraph FontWeight="Normal" FontSize="14">
                                                        <Run Text="All mods are checked against "/>
                                                        <Run FontStyle="Italic" Text="teardownmods.com"/>
                                                        <Run Text=". If you have any issues with a specific mod (or the app itself), use the "/>
                                                        <Run FontWeight="Bold" Text="Export Logs"/>
                                                        <Run Text=" button to examine the logs and include them in your report."/>
                                                    </Paragraph>
                                                    <Paragraph FontWeight="Normal" FontSize="14">
                                                        <Run Foreground="#FF006E8F" FontWeight="Bold" Text="Tip:"/>
                                                        <Run FontWeight="Bold" FontSize="16" Text=" "/>
                                                        <Run Text="If you delete a mod by mistake, you can reinstall it by selecting it, and clicking the "/>
                                                        <Run FontWeight="Bold" Text="Update All Selected Mods"/>
                                                        <Run Text=" button. Once you reload the mod list, this is no longer possible, as the mod will no longer be shown in the "/>
                                                        <Run FontStyle="Italic" Text="Installed Mods List"/>
                                                        <Run Text="."/>
                                                    </Paragraph>
                                                </FlowDocument>
                                            </RichTextBox>
                                        </ScrollViewer>
                                    </GroupBox>
                                </TabItem>
                                <TabItem Header="Installed Mods Tab" Height="35" VerticalAlignment="Top" TextOptions.TextFormattingMode="Display" FontSize="14">
                                    <GroupBox Header="Installed Mods Tab..." FontSize="16">
                                        <ScrollViewer>
                                            <RichTextBox IsReadOnlyCaretVisible="True" IsReadOnly="True">
                                                <FlowDocument>
                                                    <Paragraph FontWeight="Normal" FontSize="14" Padding="0,2,0,0">
                                                        <Run Text="Select the mods you wish to update, then click the "/>
                                                        <Run FontWeight="Bold" Text="Update All Selected Mods"/>
                                                        <Run Text=" button. This can take some time if you select a lot of mods at once. Sometimes the downloads are slow, you can export logs while processing if needed."/>
                                                    </Paragraph>
                                                    <Paragraph FontWeight="Normal" FontSize="14" Padding="0,2,0,0">
                                                        <Run Text="On app load, all mods in the default mods folder should be displayed. The Cresta weapon pack is an exception, which handles them all as a single mod."/>
                                                    </Paragraph>
                                                    <List>
                                                        <ListItem>
                                                            <Paragraph FontWeight="Normal" FontSize="14">
                                                                <Run Text="Changing the default mods location is now supported, and will automatically reload the mods list with validated mods. ** Click the mods folder path textbox to change. **"/>
                                                            </Paragraph>
                                                        </ListItem>
                                                        <ListItem>
                                                            <Paragraph FontWeight="Normal" FontSize="14">
                                                                <Run Text="Basic mod validation is used. If 'info.txt' does not exist or include mod name, it is ignored and not included in the list."/>
                                                            </Paragraph>
                                                        </ListItem>
                                                        <ListItem>
                                                            <Paragraph FontWeight="Normal" FontSize="14">
                                                                <Run Text="Make sure to back up your mods folder. By default, this is your "/>
                                                                <Run FontStyle="Italic" Text="Documents\Teardown\mods"/>
                                                                <Run Text=" folder. You may use the "/>
                                                                <Run FontWeight="Bold" Text="Backup All Mods"/>
                                                                <Run Text=" button to do this for you."/>
                                                            </Paragraph>
                                                        </ListItem>
                                                    </List>
                                                    <Paragraph FontWeight="Normal" FontSize="14">
                                                        <Run Foreground="#FF006E8F" FontWeight="Bold" Text="Note:"/>
                                                        <Run Text=" When a mod developer fixes naming consistency of a mod that was previously inconsistent, you may get an error saying the mod could not be found after extraction. This is expected. Try reloading mod list, and trying again, as the error is correct, but it still likely updated just fine."/>
                                                    </Paragraph>
                                                </FlowDocument>
                                            </RichTextBox>
                                        </ScrollViewer>
                                    </GroupBox>
                                </TabItem>
                                <TabItem Header="Backup All Mods" Height="35" VerticalAlignment="Top" TextOptions.TextFormattingMode="Display" FontSize="14">
                                    <GroupBox Header="Backup All Mods Button..." FontSize="16">
                                        <ScrollViewer>
                                            <RichTextBox IsReadOnlyCaretVisible="True" IsReadOnly="True">
                                                <FlowDocument>
                                                    <Paragraph FontWeight="Normal" FontSize="14" Padding="0,2,0,0">
                                                        <Run Text="It should be said that the first thing to be done is backing up your mods. You can do this automatically by clicking the "/>
                                                        <Run FontWeight="Bold" Text="Backup All Mods"/>
                                                        <Run Text=" button."/>
                                                    </Paragraph>
                                                    <List>
                                                        <ListItem>
                                                            <Paragraph FontWeight="Normal" FontSize="14">
                                                                <Run Text="This will back up your "/>
                                                                <Run FontStyle="Italic" Text="Documents\Teardown\mods"/>
                                                                <Run Text=" folder to a zip file: "/>
                                                                <Run FontStyle="Italic" Text="Documents\Teardown\mods_backup_132566554489856810.zip"/>
                                                                <Run Text="."/>
                                                            </Paragraph>
                                                        </ListItem>
                                                        <ListItem>
                                                            <Paragraph FontWeight="Normal" FontSize="14">
                                                                <Run Text="You can also do it manually and likely faster by copying and pasting a copy of your mods folder to somewhere else."/>
                                                            </Paragraph>
                                                        </ListItem>
                                                    </List>
                                                    <Paragraph FontWeight="Normal" FontSize="14">
                                                        <Run Foreground="#FF006E8F" FontWeight="Bold" Text="Note:"/>
                                                        <Run Text=" "/>
                                                        <Run Text="This process can take awhile depending on how big your mods folder is. It can take around 30 seconds per gig. In my test, it took about 30 seconds to back up a mods folder that is 1.4GB."/>
                                                    </Paragraph>
                                                </FlowDocument>
                                            </RichTextBox>
                                        </ScrollViewer>
                                    </GroupBox>
                                </TabItem>
                                <TabItem Header="Mod Compatibility" Height="35" VerticalAlignment="Top" TextOptions.TextFormattingMode="Display" FontSize="14">
                                    <GroupBox Header="Mod devs: to help ensure mod compatibility with Teardown Mods Manager..." FontSize="16">
                                        <ScrollViewer>
                                            <RichTextBox IsReadOnlyCaretVisible="True" IsReadOnly="True">
                                                <FlowDocument>
                                                    <Paragraph FontWeight="Normal" FontSize="14" Padding="0,2,0,0">
                                                        <Run Text="Teardown Mods Manager supports updating mods archived with 7-Zip (.7z), WinRAR (.rar), and Zip (.zip)."/>
                                                    </Paragraph>
                                                    <Paragraph FontWeight="Normal" FontSize="14" Padding="0,2,0,0">
                                                        <Run Text="As a mod creator or developer, the following practices can help ensure mod compatibility with Teardown Mods Manager:"/>
                                                    </Paragraph>
                                                    <List>
                                                        <ListItem>
                                                            <Paragraph FontWeight="Normal" FontSize="14">
                                                                <Run Text="Mod name consistency is the biggest factor in your mod working with this app."/>
                                                            </Paragraph>
                                                        </ListItem>
                                                        <ListItem>
                                                            <Paragraph FontWeight="Normal" FontSize="14">
                                                                <Run Text="Ensure mod 'name = ' in mod "/>
                                                                <Run FontStyle="Italic" Text="info.txt"/>
                                                                <Run Text=" matches the name of your mod at "/>
                                                                <Run FontStyle="Italic" Text="teardownmods.com"/>
                                                                <Run Text="."/>
                                                            </Paragraph>
                                                        </ListItem>
                                                        <ListItem>
                                                            <Paragraph FontWeight="Normal" FontSize="14">
                                                                <Run Text="Ensure mod name matches folder name, i.e. "/>
                                                                <Run FontStyle="Italic" Text="Documents\Teardown\mods\mod name"/>
                                                                <Run Text="."/>
                                                            </Paragraph>
                                                        </ListItem>
                                                        <ListItem>
                                                            <Paragraph FontWeight="Normal" FontSize="14">
                                                                <Run Text="Ensure 'version = ' in mod "/>
                                                                <Run FontStyle="Italic" Text="info.txt"/>
                                                                <Run Text=" is current released version at "/>
                                                                <Run FontStyle="Italic" Text="teardownmods.com"/>
                                                                <Run Text=". Something meaningful to the most amount of people, such as "/>
                                                                <Run FontStyle="Italic" Text="2021.01.31.x"/>
                                                                <Run Text=" or preferably "/>
                                                                <Run FontStyle="Italic" Text="1.5.2"/>
                                                                <Run Text=" for example. See semantic versioning: https://semver.org/"/>
                                                            </Paragraph>
                                                        </ListItem>
                                                        <ListItem>
                                                            <Paragraph FontWeight="Normal" FontSize="14">
                                                                <Run Text="Ensure the last file in the downloads list at "/>
                                                                <Run FontStyle="Italic" Text="teardownmods.com"/>
                                                                <Run Text=" for the mod is the regular default or preferred mod download. This app selects the last file listed to download."/>
                                                            </Paragraph>
                                                        </ListItem>
                                                        <ListItem>
                                                            <Paragraph FontWeight="Normal" FontSize="14">
                                                                <Run Text="Ensure name of mod folder is properly archived: so extracting to "/>
                                                                <Run FontStyle="Italic" Text="Teardown\mods"/>
                                                                <Run Text=" will result in "/>
                                                                <Run FontStyle="Italic" Text="Teardown\mods\Mod Name"/>
                                                            </Paragraph>
                                                        </ListItem>
                                                        <ListItem>
                                                            <Paragraph FontWeight="Normal" FontSize="14">
                                                                <Run Text="Instead of having multiple mods/maps, use mod options to control lighting, time of day, weather, etc. If that doesn't work for you, create separate mods for them on "/>
                                                                <Run FontStyle="Italic" Text="teardownmods.com"/>
                                                            </Paragraph>
                                                        </ListItem>
                                                        <ListItem>
                                                            <Paragraph FontWeight="Normal" FontSize="14">
                                                                <Run Text="Try to package mods together in the same mod folder that are part of the same mod package. That way I don't have to hard code a workaround."/>
                                                            </Paragraph>
                                                        </ListItem>
                                                    </List>
                                                </FlowDocument>
                                            </RichTextBox>
                                        </ScrollViewer>
                                    </GroupBox>
                                </TabItem>
                            </TabControl>
                        </GroupBox>
                    </DockPanel>
                </TabItem>
            </TabControl>
        </DockPanel>
    </Grid>
</Window>
"@

    $xamlReader = (New-Object System.Xml.XmlNodeReader $xaml)
    $syncHash.Window = [Windows.Markup.XamlReader]::Load( $xamlReader )

    $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") |
        ForEach-Object {
            $syncHash.($_.Name) = $syncHash.Window.FindName($_.Name)
        }

    #############################################
    #############################################
    #endRegion XML PREP
    #############################################
    #############################################

#   ██████  ███    ██       ██       ██████   █████  ██████       ██████  ██████  ██████  ███████ 
#  ██    ██ ████   ██       ██      ██    ██ ██   ██ ██   ██     ██      ██    ██ ██   ██ ██      
#  ██    ██ ██ ██  ██ █████ ██      ██    ██ ███████ ██   ██     ██      ██    ██ ██   ██ █████   
#  ██    ██ ██  ██ ██       ██      ██    ██ ██   ██ ██   ██     ██      ██    ██ ██   ██ ██      
#   ██████  ██   ████       ███████  ██████  ██   ██ ██████       ██████  ██████  ██████  ███████ 

    #region ONLOAD CODE

    Update-Window -Control SelectDefaultModsLocation -Property Text -Value "$env:USERPROFILE\Documents\Teardown\Mods"

    "Invoking mod table layout and prep" | Write-Log
    Invoke-TablePrep

    "Getting mod file details" | Write-Log
    $syncHash.allModsDeetz = Get-ModDeets

    foreach ($modItem in $syncHash.allModsDeetz) {
        "Refreshing mod row [$($modItem.ModName)]" | Write-Log

        $row = $syncHash.dataTable.NewRow()

            $row.ModName            = ($modItem.ModName -replace '[^a-zA-Z0-9 .]','')
            $row.ModVersion         = $modItem.ModVersion
            $row.ModAuthor          = $modItem.ModAuthor
            $row.ModDescription     = $modItem.ModDescription
            $row.ModPath            = $modItem.ModPath
            $row.ModWebpage         = $modItem.ModWebPage
            $row.ModDownloadLink    = $modItem.ModDownloadLink

        [void]$syncHash.dataTable.Rows.Add($row)
    }

    "Finished initial loading of mod list" | Write-Log

    #############################################
    #############################################
    #endRegion ONLOAD CODE
    #############################################
    #############################################

#  ██████  ███████ ██       ██████   █████  ██████      ███    ███  ██████  ██████      ██      ██ ███████ ████████     ██████  ██    ██ ████████ ████████  ██████  ███    ██ 
#  ██   ██ ██      ██      ██    ██ ██   ██ ██   ██     ████  ████ ██    ██ ██   ██     ██      ██ ██         ██        ██   ██ ██    ██    ██       ██    ██    ██ ████   ██ 
#  ██████  █████   ██      ██    ██ ███████ ██   ██     ██ ████ ██ ██    ██ ██   ██     ██      ██ ███████    ██        ██████  ██    ██    ██       ██    ██    ██ ██ ██  ██ 
#  ██   ██ ██      ██      ██    ██ ██   ██ ██   ██     ██  ██  ██ ██    ██ ██   ██     ██      ██      ██    ██        ██   ██ ██    ██    ██       ██    ██    ██ ██  ██ ██ 
#  ██   ██ ███████ ███████  ██████  ██   ██ ██████      ██      ██  ██████  ██████      ███████ ██ ███████    ██        ██████   ██████     ██       ██     ██████  ██   ████ 

    #region RELOAD MOD LIST BUTTON
    $syncHash.ReloadModList.Add_Click({
        "Clicked 'Reload Mod List' button" | Write-Log

        Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"

        "Invoking mod table layout and prep" | Write-Log
        Invoke-TablePrep

        "Getting mod file details" | Write-Log
        if ($syncHash.folderSelectDialog.SelectedPath.Length -gt 2) {
            $syncHash.allModsDeetz = Get-ModDeets -ModDir $syncHash.folderSelectDialog.SelectedPath
            $statusBarTextFinish = "Finished reloading new mod list [$($syncHash.folderSelectDialog.SelectedPath)]. Ready..."
        } else {
            $syncHash.allModsDeetz = Get-ModDeets
        }
    
        foreach ($modItem in $syncHash.allModsDeetz) {
            "Refreshing mod row [$($modItem.ModName)]" | Write-Log
    
            $row = $syncHash.dataTable.NewRow()
    
                $row.ModName            = ($modItem.ModName -replace '[^a-zA-Z0-9 .]','')
                $row.ModVersion         = $modItem.ModVersion
                $row.ModAuthor          = $modItem.ModAuthor
                $row.ModDescription     = $modItem.ModDescription
                $row.ModPath            = $modItem.ModPath
                $row.ModWebpage         = $modItem.ModWebPage
                $row.ModDownloadLink    = $modItem.ModDownloadLink
    
            [void]$syncHash.dataTable.Rows.Add($row)
        }

        if ($statusBarTextFinish) {
            Update-Window -Control StatusBarText -Property Text -Value $statusBarTextFinish
        } else {Update-Window -Control StatusBarText -Property Text -Value "Finished reloading mod list. Ready..."}
        Update-Window -Control ProgressBar -Property "Value" -Value 0

    })

    #############################################
    #############################################
    #endRegion RELOAD MOD LIST BUTTON
    #############################################
    #############################################

#  ██    ██ ██████  ██████   █████  ████████ ███████      █████  ██      ██          ███████ ███████ ██      ███████  ██████ ████████ ███████ ██████      ███    ███  ██████  ██████  ███████ 
#  ██    ██ ██   ██ ██   ██ ██   ██    ██    ██          ██   ██ ██      ██          ██      ██      ██      ██      ██         ██    ██      ██   ██     ████  ████ ██    ██ ██   ██ ██      
#  ██    ██ ██████  ██   ██ ███████    ██    █████       ███████ ██      ██          ███████ █████   ██      █████   ██         ██    █████   ██   ██     ██ ████ ██ ██    ██ ██   ██ ███████ 
#  ██    ██ ██      ██   ██ ██   ██    ██    ██          ██   ██ ██      ██               ██ ██      ██      ██      ██         ██    ██      ██   ██     ██  ██  ██ ██    ██ ██   ██      ██ 
#   ██████  ██      ██████  ██   ██    ██    ███████     ██   ██ ███████ ███████     ███████ ███████ ███████ ███████  ██████    ██    ███████ ██████      ██      ██  ██████  ██████  ███████ 

    #region UPDATE ALL MODS BUTTON
    $syncHash.UpdateAllSelectedMods.Add_Click({
        "Clicked 'Update All Mods' button" | Write-Log

        # Defines the Teardown mods folder to use throughout below logic
        $modsFolderPath = if ($syncHash.folderSelectDialog.SelectedPath) {$syncHash.folderSelectDialog.SelectedPath} else {"$env:USERPROFILE\Documents\Teardown\mods"}

        Update-Window -Control ProgressBar -Property "Value" -Value 0
        Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"

        "Building mods list from selected cells" | Write-Log
        $selectedCells = foreach ($selectedCellRow in $syncHash.ModsListDataGrid.SelectedCells) {
            [PSCustomObject]@{
                'ModName'           = $selectedCellRow.Item.modName -replace "\|(.*)\| ",''
                'ModVersion'        = $selectedCellRow.Item.modVersion
                'ModAuthor'         = $selectedCellRow.Item.modAuthor
                'ModDescription'    = $selectedCellRow.Item.modDescription
                'ModPath'           = $selectedCellRow.Item.ModPath
                'ModWebPage'        = if ($selectedCellRow.Item.modWebLink.Length -gt 25) {$selectedCellRow.Item.modWebLink} else {"NA"}
                'ModDownloadLink'   = if ($selectedCellRow.Item.modPackageDownloadLink.Length -gt 25) {$selectedCellRow.Item.modPackageDownloadLink} else {"NA"}
            }
        }

        $selectedMods = (($selectedCells | Group-Object -Property ModName).Name) | Where-Object {$_ -cne 'Mod Name'}
        "Selected mods are [$($selectedMods -join ', ')]" | Write-Log

        if (-not ($selectedMods)) {
            Update-Window -Control StatusBarText -Property Text -Value "No mod selected. Please select a mod and try again!"
        } else {

            $UpdateAllSelectedModsRunspace = [runspacefactory]::CreateRunspace()
            $UpdateAllSelectedModsRunspace.Name = "UpdateAllSelectedModsRunspace"
            $UpdateAllSelectedModsRunspace.ApartmentState = "STA"
            $UpdateAllSelectedModsRunspace.ThreadOptions = "ReuseThread"
            $UpdateAllSelectedModsRunspace.Open()
            $UpdateAllSelectedModsRunspace.SessionStateProxy.SetVariable("syncHash", $syncHash)
            $UpdateAllSelectedModsRunspace.SessionStateProxy.SetVariable("modsFolderPath", $modsFolderPath)
            $UpdateAllSelectedModsRunspace.SessionStateProxy.SetVariable("selectedMods", $selectedMods)

            $UpdateAllSelectedModsRunspaceScript = [PowerShell]::Create().AddScript({

                "Created new runspace for 'Update All Mods'" | Write-Log

                #############################################
                #region FUNCTIONS
                #############################################

                function Write-Log {
                    [CmdletBinding()]
                    Param (
                        [Parameter(ValueFromPipeline=$true,Mandatory,Position=0)]
                        [string]$Message,
                        [switch]$ClearLog,
                        [switch]$WriteOut
                    )
                
                    begin {
                        if (($ClearLog) -or ($syncHash.tmmLog -notmatch "Log initialized:")) {
                            $syncHash.tmmLog = @"

Log initialized: $(Get-Date)

"@
                        }
                    }
                
                    process {
                        $timestamp = "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')"
                        $logText = "[$timestamp]`t$Message"
                        $syncHash.tmmLog += "`n$logText"
                    }
                
                    end {
                        if ($WriteOut) {
                            Write-Output -InputObject $syncHash.tmmLog
                        }
                    }
                
                }

                Function Get-InstalledApplication {
                    <#
                    .SYNOPSIS
                        Retrieves information about installed applications.
                    .DESCRIPTION
                        Retrieves information about installed applications by querying the registry. You can specify an application name, a product code, or both.
                        Returns information about application publisher, name & version, product code, uninstall string, install source, location, date, and application architecture.
                    .PARAMETER Name
                        The name of the application to retrieve information for. Performs a contains match on the application display name by default.
                    .PARAMETER Exact
                        Specifies that the named application must be matched using the exact name.
                    .PARAMETER WildCard
                        Specifies that the named application must be matched using a wildcard search.
                    .PARAMETER RegEx
                        Specifies that the named application must be matched using a regular expression search.
                    .PARAMETER ProductCode
                        The product code of the application to retrieve information for.
                    .PARAMETER IncludeUpdatesAndHotfixes
                        Include matches against updates and hotfixes in results.
                    .EXAMPLE
                        Get-InstalledApplication -Name 'Adobe Flash'
                    .EXAMPLE
                        Get-InstalledApplication -ProductCode '{1AD147D0-BE0E-3D6C-AC11-64F6DC4163F1}'
                    .NOTES
                    .LINK
                        http://psappdeploytoolkit.com
                    #>
                    [CmdletBinding()]
                    Param (
                        [Parameter(Mandatory=$false)]
                        [ValidateNotNullorEmpty()]
                        [string[]]$Name,
                        [Parameter(Mandatory=$false)]
                        [switch]$Exact = $false,
                        [Parameter(Mandatory=$false)]
                        [switch]$WildCard = $false,
                        [Parameter(Mandatory=$false)]
                        [switch]$RegEx = $false,
                        [Parameter(Mandatory=$false)]
                        [ValidateNotNullorEmpty()]
                        [string]$ProductCode,
                        [Parameter(Mandatory=$false)]
                        [switch]$IncludeUpdatesAndHotfixes
                    )

                    Begin {
                        #  Get the OS Architecture
                        [boolean]$Is64Bit = [boolean]((Get-WmiObject -Class 'Win32_Processor' -ErrorAction 'SilentlyContinue' | Where-Object { $_.DeviceID -eq 'CPU0' } | Select-Object -ExpandProperty 'AddressWidth') -eq 64)
                        If ($Is64Bit) { [string]$envOSArchitecture = '64-bit' } Else { [string]$envOSArchitecture = '32-bit' }

                        ## Variables: Current Process Architecture
                        [boolean]$Is64BitProcess = [boolean]([IntPtr]::Size -eq 8)
                        If ($Is64BitProcess) { [string]$psArchitecture = 'x64' } Else { [string]$psArchitecture = 'x86' }


                        ## Variables: Registry Keys
                        #  Registry keys for native and WOW64 applications
                        [string[]]$regKeyApplications = 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
                        If ($is64Bit) {
                            [string]$regKeyLotusNotes = 'HKLM:SOFTWARE\Wow6432Node\Lotus\Notes'
                        }
                        Else {
                            [string]$regKeyLotusNotes = 'HKLM:SOFTWARE\Lotus\Notes'
                        }
                        [string]$regKeyAppExecution = 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
                    }
                    Process {
                        ## Enumerate the installed applications from the registry for applications that have the "DisplayName" property
                        [psobject[]]$regKeyApplication = @()
                        ForEach ($regKey in $regKeyApplications) {
                            If (Test-Path -LiteralPath $regKey -ErrorAction 'SilentlyContinue' -ErrorVariable '+ErrorUninstallKeyPath') {
                                [psobject[]]$UninstallKeyApps = Get-ChildItem -LiteralPath $regKey -ErrorAction 'SilentlyContinue' -ErrorVariable '+ErrorUninstallKeyPath'
                                ForEach ($UninstallKeyApp in $UninstallKeyApps) {
                                    Try {
                                        [psobject]$regKeyApplicationProps = Get-ItemProperty -LiteralPath $UninstallKeyApp.PSPath -ErrorAction 'Stop'
                                        If ($regKeyApplicationProps.DisplayName) { [psobject[]]$regKeyApplication += $regKeyApplicationProps }
                                    }
                                    Catch{
                                        Continue
                                    }
                                }
                            }
                        }

                        ## Create a custom object with the desired properties for the installed applications and sanitize property details
                        [psobject[]]$installedApplication = @()
                        ForEach ($regKeyApp in $regKeyApplication) {
                            Try {
                                [string]$appDisplayName = ''
                                [string]$appDisplayVersion = ''
                                [string]$appPublisher = ''

                                ## Bypass any updates or hotfixes
                                If (-not $IncludeUpdatesAndHotfixes) {
                                    If ($regKeyApp.DisplayName -match '(?i)kb\d+') { Continue }
                                    If ($regKeyApp.DisplayName -match 'Cumulative Update') { Continue }
                                    If ($regKeyApp.DisplayName -match 'Security Update') { Continue }
                                    If ($regKeyApp.DisplayName -match 'Hotfix') { Continue }
                                }

                                ## Remove any control characters which may interfere with logging and creating file path names from these variables
                                $illegalChars = [string][System.IO.Path]::GetInvalidFileNameChars()
                                $appDisplayName = $regKeyApp.DisplayName -replace $illegalChars,''
                                $appDisplayVersion = $regKeyApp.DisplayVersion -replace $illegalChars,''
                                $appPublisher = $regKeyApp.Publisher -replace $illegalChars,''


                                ## Determine if application is a 64-bit application
                                [boolean]$Is64BitApp = If (($is64Bit) -and ($regKeyApp.PSPath -notmatch '^Microsoft\.PowerShell\.Core\\Registry::HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node')) { $true } Else { $false }

                                If ($ProductCode) {
                                    ## Verify if there is a match with the product code passed to the script
                                    If ($regKeyApp.PSChildName -match [regex]::Escape($productCode)) {
                                        $installedApplication += New-Object -TypeName 'PSObject' -Property @{
                                            UninstallSubkey = $regKeyApp.PSChildName
                                            ProductCode = If ($regKeyApp.PSChildName -match $MSIProductCodeRegExPattern) { $regKeyApp.PSChildName } Else { [string]::Empty }
                                            DisplayName = $appDisplayName
                                            DisplayVersion = $appDisplayVersion
                                            UninstallString = $regKeyApp.UninstallString
                                            InstallSource = $regKeyApp.InstallSource
                                            InstallLocation = $regKeyApp.InstallLocation
                                            InstallDate = $regKeyApp.InstallDate
                                            Publisher = $appPublisher
                                            Is64BitApplication = $Is64BitApp
                                        }
                                    }
                                }

                                If ($name) {
                                    ## Verify if there is a match with the application name(s) passed to the script
                                    ForEach ($application in $Name) {
                                        $applicationMatched = $false
                                        If ($exact) {
                                            #  Check for an exact application name match
                                            If ($regKeyApp.DisplayName -eq $application) {
                                                $applicationMatched = $true
                                            }
                                        }
                                        ElseIf ($WildCard) {
                                            #  Check for wildcard application name match
                                            If ($regKeyApp.DisplayName -like $application) {
                                                $applicationMatched = $true
                                            }
                                        }
                                        ElseIf ($RegEx) {
                                            #  Check for a regex application name match
                                            If ($regKeyApp.DisplayName -match $application) {
                                                $applicationMatched = $true
                                            }
                                        }
                                        #  Check for a contains application name match
                                        ElseIf ($regKeyApp.DisplayName -match [regex]::Escape($application)) {
                                            $applicationMatched = $true
                                        }

                                        If ($applicationMatched) {
                                            $installedApplication += New-Object -TypeName 'PSObject' -Property @{
                                                UninstallSubkey = $regKeyApp.PSChildName
                                                ProductCode = If ($regKeyApp.PSChildName -match $MSIProductCodeRegExPattern) { $regKeyApp.PSChildName } Else { [string]::Empty }
                                                DisplayName = $appDisplayName
                                                DisplayVersion = $appDisplayVersion
                                                UninstallString = $regKeyApp.UninstallString
                                                InstallSource = $regKeyApp.InstallSource
                                                InstallLocation = $regKeyApp.InstallLocation
                                                InstallDate = $regKeyApp.InstallDate
                                                Publisher = $appPublisher
                                                Is64BitApplication = $Is64BitApp
                                            }
                                        }
                                    }
                                }
                            }
                            Catch {
                                Continue
                            }
                        }
                        Write-Output -InputObject $installedApplication
                    }
                    End {}
                }

                Function Update-Window {
                    Param (
                        $Control,
                        $Property,
                        $Value,
                        [switch]$AppendContent
                    )
                    If ($Property -eq "Close") {
                        $syncHash.Window.Dispatcher.invoke([action]{$syncHash.Window.Close()},"Normal")
                        Return
                    }
                    $syncHash.$Control.Dispatcher.Invoke([action]{
                        If ($PSBoundParameters['AppendContent']) {
                            $syncHash.$Control.AppendText($Value)
                        } Else {
                            $syncHash.$Control.$Property = $Value
                        }
                    }, "Normal")

                    if ($Control -eq 'StatusBarText' -and $Property -eq 'Text') {
                        Write-Log -Message $Value
                    }

                }

                #############################################
                #endRegion FUNCTIONS
                #############################################

                #############################################
                #############################################
                #region UPDATE ALL MODS BUTTON LOGIC
                #############################################
                #############################################

                # Check if 7-Zip or WinRAR is installed:
                Update-Window -Control StatusBarText -Property Text -Value "Checking if 7-Zip or WinRAR is installed on system..."
                $7zApp = Get-InstalledApplication -Name "7-Zip"
                $wrarApp = Get-InstalledApplication -Name "WinRAR"
                if ((Test-Path -Path "$($7zApp.InstallLocation)7z.exe") -eq $true) {
                    Update-Window -Control StatusBarText -Property Text -Value "7-Zip installation detected!..."
                    $7zExePath = "$($7zApp.InstallLocation)7z.exe"
                    $7zInstalled = $true
                    $zipOnly = $false
                } elseif ((Test-Path -Path "$($wrarApp.InstallLocation)UnRAR.exe") -eq $true) {
                    Update-Window -Control StatusBarText -Property Text -Value "WinRAR installation detected!..."
                    $wrarExePath =  "$($wrarApp.InstallLocation)UnRAR.exe"
                    $wrarInstalled = $true
                    $zipOnly = $false
                } else {
                    Update-Window -Control StatusBarText -Property Text -Value "7-Zip and WinRAR was NOT detected as installed on system..."
                    $zipOnly = $true
                }

                $syncHash.selectedModsList = $syncHash.allModsDeetz | Where-Object {$selectedMods -match ($_.ModName -replace '[^a-zA-Z0-9 .]','')}

                $syncHash.allModsUpdateTotal = $syncHash.selectedModsList.ModName.Count
                $syncHash.allModsUpdateCount = 1
                foreach ($modDeetz in $syncHash.selectedModsList) {

                    if ((Get-Runspace | Where-Object { $_.RunspaceAvailability -eq "Busy" }).Count -gt 4) {
                        do {
                            Start-Sleep -Seconds 2
                        } while ((Get-Runspace | Where-Object { $_.RunspaceAvailability -eq "Busy" }).Count -gt 4)
                    }

                    Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
                    Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"

                    $rowSearch = $modDeetz.ModName -replace '[^a-zA-Z0-9 .]',''
                    $cellOriginal = ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName -replace "\|(.*)\| ",''
                    ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Starting update... | $cellOriginal"
                    "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Starting update... | $cellOriginal]" | Write-Log

                    $UpdateAllSelectedModsRunspaceSpawn = [runspacefactory]::CreateRunspace()
                    $UpdateAllSelectedModsRunspaceSpawn.Name = "UpdateAllSelectedModsRunspaceSpawn"
                    $UpdateAllSelectedModsRunspaceSpawn.ApartmentState = "STA"
                    $UpdateAllSelectedModsRunspaceSpawn.ThreadOptions = "ReuseThread"
                    $UpdateAllSelectedModsRunspaceSpawn.Open()
                    $UpdateAllSelectedModsRunspaceSpawn.SessionStateProxy.SetVariable("syncHash", $syncHash)
                    $UpdateAllSelectedModsRunspaceSpawn.SessionStateProxy.SetVariable("modDeetz", $modDeetz)
                    $UpdateAllSelectedModsRunspaceSpawn.SessionStateProxy.SetVariable("cellOriginal", $cellOriginal)
                    $UpdateAllSelectedModsRunspaceSpawn.SessionStateProxy.SetVariable("7zApp", $7zApp)
                    $UpdateAllSelectedModsRunspaceSpawn.SessionStateProxy.SetVariable("wrarApp", $wrarApp)
                    $UpdateAllSelectedModsRunspaceSpawn.SessionStateProxy.SetVariable("7zExePath", $7zExePath)
                    $UpdateAllSelectedModsRunspaceSpawn.SessionStateProxy.SetVariable("7zInstalled", $7zInstalled)
                    $UpdateAllSelectedModsRunspaceSpawn.SessionStateProxy.SetVariable("zipOnly", $zipOnly)
                    $UpdateAllSelectedModsRunspaceSpawn.SessionStateProxy.SetVariable("wrarExePath", $wrarExePath)
                    $UpdateAllSelectedModsRunspaceSpawn.SessionStateProxy.SetVariable("wrarInstalled", $wrarInstalled)
                    $UpdateAllSelectedModsRunspaceSpawn.SessionStateProxy.SetVariable("rowSearch", $rowSearch)
                    $UpdateAllSelectedModsRunspaceSpawn.SessionStateProxy.SetVariable("modsFolderPath", $modsFolderPath)
                    

                    $UpdateAllSelectedModsRunspaceSpawnScript = [PowerShell]::Create().AddScript({

                        #############################################
                        #region FUNCTIONS
                        #############################################

                        function Write-Log {
                            [CmdletBinding()]
                            Param (
                                [Parameter(ValueFromPipeline=$true,Mandatory,Position=0)]
                                [string]$Message,
                                [switch]$ClearLog,
                                [switch]$WriteOut
                            )
                        
                            begin {
                                if (($ClearLog) -or ($syncHash.tmmLog -notmatch "Log initialized:")) {
                                    $syncHash.tmmLog = @"
        
Log initialized: $(Get-Date)

"@
                                }
                            }
                        
                            process {
                                $timestamp = "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')"
                                $logText = "[$timestamp]`t$Message"
                                $syncHash.tmmLog += "`n$logText"
                            }
                        
                            end {
                                if ($WriteOut) {
                                    Write-Output -InputObject $syncHash.tmmLog
                                }
                            }
                        
                        }

                        function Get-ModData {
                            [CmdletBinding()]
                            param (
                                [String]$ModDir,
                                $allMods
                            )
                            
                            begin {}
                            
                            process {
                        
                                $allModsData = foreach ($mod in $allMods) {
                                    $modSearchName = $mod.modSearchName
                                    $modName = $mod.ModName
                                    $modVersion = $mod.ModVersion
                                    $modAuthor = $mod.ModAuthor
                                    $modDescription = $mod.ModDescription
                                    $modSearchURI = "https://teardownmods.com/index.php?/search/&q=" + ($modSearchName -replace " ",'%20' -replace "_",'%20' -replace "'s",'') + "&search_and_or=or&sortby=relevancy"
                                    Update-Window -Control StatusBarText -Property Text -Value "Searching teardownmods.com for [$modSearchName]..."
                                    $modSearchResults = Invoke-WebRequest $modSearchURI -UseBasicParsing -ErrorAction SilentlyContinue
                                    $modWebLink = ($modSearchResults.Links | Where-Object {$_.outerHTML -match $modSearchName -and $_.href -match "getNewComment"} | Select-Object -First 1).href -replace '&amp;','&'
                                    if (-not $modWebLink) {
                                        $modSearchNameSplit = $modName -split " "
                                        $modSearchName = $modSearchNameSplit[0] -replace "'s",''
                                        $modSearchURI = "https://teardownmods.com/index.php?/search/&q=" + ($modSearchName -replace " ",'%20' -replace "_",'%20' -replace "'s",'') + "&search_and_or=or&sortby=relevancy"
                                        $modSearchResults = Invoke-WebRequest $modSearchURI -UseBasicParsing -ErrorAction SilentlyContinue
                                        $modWebLink = ($modSearchResults.Links | Where-Object {$_.outerHTML -match $modSearchName -and $_.href -match "getNewComment"} | Select-Object -First 1).href -replace '&amp;','&'
                                    }
                                    if (-not $modWebLink) {
                                        if ($modName -match "vechicles") {
                                            $modSearchName = 'Every vechicle'
                                            $modSearchURI = "https://teardownmods.com/index.php?/search/&q=" + ($modSearchName -replace " ",'%20' -replace "_",'%20' -replace "'s",'') + "&search_and_or=or&sortby=relevancy"
                                            $modSearchResults = Invoke-WebRequest $modSearchURI -UseBasicParsing -ErrorAction SilentlyContinue
                                            $modWebLink = ($modSearchResults.Links | Where-Object {$_.outerHTML -match $modSearchName -and $_.href -match "getNewComment"} | Select-Object -First 1).href -replace '&amp;','&'
                                        }
                                    }
                        
                                    if ($modWebLink) {
                                        $modWebPage = Invoke-WebRequest -Uri $modWebLink -SessionVariable mwp -UseBasicParsing -ErrorAction SilentlyContinue
                                        $syncHash.mwp = $mwp
                                        $modDownloadLink = ($modWebPage.Links | Where-Object {$_ -match '&amp;do=download&amp;csrfKey='} | Select-Object -First 1).href -replace '&amp;','&'
                                        Update-Window -Control StatusBarText -Property Text -Value "Accessing [$modName] mod download page at teardownmods.com..."
                                        $modPackageDownloadPage = Invoke-WebRequest -Uri $modDownloadLink -Method Get -WebSession $syncHash.mwp -UseBasicParsing -ErrorAction SilentlyContinue
                                        $modPackageDownloadLink = ($modPackageDownloadPage.Links | Where-Object {$_.'data-action' -eq 'download'} | Select-Object -Last 1).href -replace '&amp;','&'
                                        Update-Window -Control StatusBarText -Property Text -Value "Assuming [$modName] mod package download link at teardownmods.com..."
                                    } else {
                                        ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Update failed, try again later... | $cellOriginal"
                                        "Setting [$($mod.ModName)] 'Mod Name' cell text update process status to [| Update failed, try again later... | $cellOriginal]" | Write-Log
                                        Update-Window -Control StatusBarText -Property Text -Value "ERROR: Cannot find mod web link from teardownmods.com search results..."
                                    }
                                
                                    [PSCustomObject]@{
                                        'ModName'           = $modName
                                        'ModVersion'        = $modVersion
                                        'ModAuthor'         = $modAuthor
                                        'ModDescription'    = $modDescription
                                        'ModPath'           = $mod.ModPath
                                        'ModWebPage'        = if ($modWebLink.Length -gt 25) {$modWebLink} else {"Not Found"}
                                        'ModDownloadLink'   = if ($modPackageDownloadLink.Length -gt 25) {$modPackageDownloadLink} else {"Not Found"}
                                        'WebSession'        = $mwp
                                    }
                                
                                    $modInfo = $null
                                    $modName = $null
                                    $modVersion = $null
                                    $modAuthor = $null
                                    $modDescription = $null
                                    $modSearchURI = $null
                                    $modSearchResults = $null
                                    $modWebPage = $null
                                    $modDownloadLink = $null
                                    $modPackageDownloadPage = $null
                                    $modPackageDownloadLink = $null
                                }
                        
                            }
                            
                            end {
                        
                                Write-Output -InputObject $allModsData
                                
                            }
                        }

                        Function Update-Window {
                            Param (
                                $Control,
                                $Property,
                                $Value,
                                [switch]$AppendContent
                            )
                            If ($Property -eq "Close") {
                                $syncHash.Window.Dispatcher.invoke([action]{$syncHash.Window.Close()},"Normal")
                                Return
                            }
                            $syncHash.$Control.Dispatcher.Invoke([action]{
                                If ($PSBoundParameters['AppendContent']) {
                                    $syncHash.$Control.AppendText($Value)
                                } Else {
                                    $syncHash.$Control.$Property = $Value
                                }
                            }, "Normal")

                            if ($Control -eq 'StatusBarText' -and $Property -eq 'Text') {
                                Write-Log -Message $Value
                            }

                        }

                        #############################################
                        #endRegion FUNCTIONS
                        #############################################

                        "Created new runspace spawn for 'Update All Mods' mod [$($modDeetz.ModName)]" | Write-Log

                        ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Getting mod data... | $cellOriginal"

                        "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Getting mod data... | $cellOriginal" | Write-Log
                        $allModsData = Get-ModData -allMods $modDeetz

                        foreach ($modItem in $allModsData) {
                            Update-Window -Control StatusBarText -Property Text -Value "Retrieving mod download info for [$($modItem.modName)]..."

                            ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModWebPage = $modItem.ModWebPage
                            ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModDownloadLink = $modItem.ModDownloadLink

                            ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Testing mod download... | $cellOriginal"
                            "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Testing mod download... | $cellOriginal" | Write-Log

                            # Test download package archive type, verify if .zip only:
                            Update-Window -Control StatusBarText -Property Text -Value "Testing [$($modItem.modName)] download link for archive type..."
                            $dlFileTestRequest = Invoke-WebRequest -Uri $modItem.ModDownloadLink -Method Head -WebSession $modItem.WebSession -UseBasicParsing -ErrorAction SilentlyContinue -ErrorVariable DLTESTERR
                            $dlFileTestName = $dlFileTestRequest.Headers.'Content-Disposition' -split "\." -replace """",'' | Select-Object -Last 1
                            if ($dlFileTestName -ne "zip" -and $zipOnly -eq $true) {
                                Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                                Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                                $DLTESTERRCUSTOM = if ($DLTESTERR) {
                                    "ERROR: Something happened, try updating mod again! - [$($dlFileTestRequest.Headers.'Content-Disposition')] - $DLTESTERR"
                                } else {
                                    "ERROR: Mod package [$($modItem.modName)] is not a .zip archive [$($dlFileTestRequest.Headers.'Content-Disposition')]. Please install 7-Zip or WinRAR!"
                                }
                                ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Update failed, try again later... | $cellOriginal"
                                "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Update failed, try again later... | $cellOriginal]" | Write-Log
                                Update-Window -Control StatusBarText -Property Text -Value "$DLTESTERRCUSTOM"
                                $syncHash.progressBarValue = [int](100/$syncHash.allModsUpdateTotal*$syncHash.allModsUpdateCount)
                                Update-Window -Control ProgressBar -Property "Value" -Value $syncHash.progressBarValue
                                $syncHash.allModsUpdateCount++
                                Continue
                            }

                            $outFile = "$($modItem.modName).$dlFileTestName"
                            $newDir = New-Item -Path "$env:TEMP\TeardownMods" -ItemType Directory -Force
                            $outFilePath = "$env:TEMP\TeardownMods\$outFile"
                            Update-Window -Control StatusBarText -Property Text -Value "Package to download is detected as [.$dlFileTestName]"

                            Update-Window -Control StatusBarText -Property Text -Value "Downloading [$($modItem.modName)] mod..."
                            ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Downloading mod... | $cellOriginal"
                            "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Downloading mod... | $cellOriginal" | Write-Log
                            Invoke-WebRequest -Uri $modItem.ModDownloadLink -OutFile $outFilePath -WebSession $modItem.WebSession -UseBasicParsing -ErrorAction SilentlyContinue -ErrorVariable DLERR
                            if (-not (Test-Path -Path $outFilePath -PathType Leaf)) {
                                Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                                Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                                ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Update failed, try again later... | $cellOriginal"
                                "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Update failed, try again later... | $cellOriginal]" | Write-Log
                                Update-Window -Control StatusBarText -Property Text -Value "ERROR: There was a problem downloading mod: [$($modItem.modName)], from URL: [$($modItem.ModDownloadLink)], to local file path: [$($outFilePath)]. Please submit this in a GitHub issue."
                                $syncHash.progressBarValue = [int](100/$syncHash.allModsUpdateTotal*$syncHash.allModsUpdateCount)
                                Update-Window -Control ProgressBar -Property "Value" -Value $syncHash.progressBarValue
                                $syncHash.allModsUpdateCount++
                                Continue
                            }

                            Update-Window -Control StatusBarText -Property Text -Value "[$($modItem.modName)] mod package download finished..."

                            Update-Window -Control StatusBarText -Property Text -Value "Removing old version of [$($modItem.modName)] mod..."
                            ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Removing old version... | $cellOriginal"
                            "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Removing old version... | $cellOriginal" | Write-Log

                            if ($modItem.modName -eq "Functional Weapon Pack") {
                                $CrestaWpnPckList = @(
                                    '500 Magnum'
                                    'AC130 Airstrike'
                                    'AK-47'
                                    'AWP'
                                    'Black Hole'
                                    'Charge Shotgun'
                                    'Desert Eagle'
                                    'Dragonslayer'
                                    'Dual Berettas'
                                    'Dual Miniguns'
                                    'Exploding Star'
                                    'Guided Missile'
                                    'Hadouken'
                                    'Holy Grenade'
                                    'Laser Cutter'
                                    'Lightkatana'
                                    'M4A1'
                                    'M249'
                                    'Magic Bag'
                                    'MGL'
                                    'Minigun'
                                    'Mjolner'
                                    'Nova'
                                    'P90'
                                    'RPG'
                                    'SCAR-20'
                                    'Scorpion'
                                    'SG-553'
                                )

                                foreach ($wpnMod in $CrestaWpnPckList) {

                                    Remove-Item -Path "$modsFolderPath\$wpnMod" -Recurse -Force

                                    # Verify old version of mod was removed from mods directory:
                                    if ((Test-Path -Path "$modsFolderPath\$wpnMod") -eq $true) {
                                        Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                                        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                                        ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Update failed, try again later... | $cellOriginal"
                                        "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Update failed, try again later... | $cellOriginal]" | Write-Log
                                        Update-Window -Control StatusBarText -Property Text -Value "ERROR: There was a problem removing old mod version folder: [$modsFolderPath\$wpnMod]."
                                        $syncHash.progressBarValue = [int](100/$syncHash.allModsUpdateTotal*$syncHash.allModsUpdateCount)
                                        Update-Window -Control ProgressBar -Property "Value" -Value $syncHash.progressBarValue
                                        $syncHash.allModsUpdateCount++
                                        Break
                                    }

                                }

                                ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Extracting mod package... | $cellOriginal"
                                "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Extracting mod package... | $cellOriginal" | Write-Log
                                Update-Window -Control StatusBarText -Property Text -Value "Extracting [$outFilePath] to [$modsFolderPath]..."

                                if ($7zInstalled -eq $true) {
                                    $argumentList = @('x', ('"'+$outFilePath+'"'), ('"-o'+$modsFolderPath+'"'), '-y')
                                    Start-Process -FilePath "$7zExePath" -ArgumentList $argumentList -WindowStyle Hidden -Wait
                                } elseif ($wrarInstalled -eq $true -and $dlFileTestName -eq "rar") {
                                    $argumentList = @("x -y", ('"'+$outFilePath+'"'), ('"'+$modsFolderPath+'"'))
                                    Start-Process -FilePath "$wrarExePath" -ArgumentList $argumentList -WindowStyle Hidden -Wait
                                } else {
                                    Expand-Archive -Path $outFilePath -DestinationPath $modsFolderPath -Force -ErrorAction SilentlyContinue -ErrorVariable EXARERR
                                }

                                foreach ($wpnMod in $CrestaWpnPckList) {

                                    # Verify new mod has been successfully extracted to mods folder:
                                    if ((Test-Path -Path "$modsFolderPath\$wpnMod") -eq $false) {
                                        Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                                        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                                        ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Update failed, try again later... | $cellOriginal"
                                        "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Update failed, try again later... | $cellOriginal]" | Write-Log
                                        Update-Window -Control StatusBarText -Property Text -Value "ERROR: Mod folder [$("$modsFolderPath\$wpnMod")] was not detected after [$dlFileTestName] archive extraction to mods folder. Please create GitHub issue."
                                        $syncHash.progressBarValue = [int](100/$syncHash.allModsUpdateTotal*$syncHash.allModsUpdateCount)
                                        Update-Window -Control ProgressBar -Property "Value" -Value $syncHash.progressBarValue
                                        $syncHash.allModsUpdateCount++
                                        Break
                                    }

                                }

                            } else {

                                Remove-Item -Path $modItem.ModPath -Recurse -Force

                                # Verify old version of mod was removed from mods directory:
                                if ((Test-Path -Path $modItem.ModPath) -eq $true) {
                                    Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                                    Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                                    Update-Window -Control StatusBarText -Property Text -Value "ERROR: There was a problem removing old mod version folder: [$($modItem.ModPath)]."
                                    ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Update failed, try again later... | $cellOriginal"
                                    "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Update failed, try again later... | $cellOriginal]" | Write-Log
                                    $syncHash.progressBarValue = [int](100/$syncHash.allModsUpdateTotal*$syncHash.allModsUpdateCount)
                                    Update-Window -Control ProgressBar -Property "Value" -Value $syncHash.progressBarValue
                                    $syncHash.allModsUpdateCount++
                                    Continue
                                }

                                ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Extracting mod package... | $cellOriginal"
                                "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Extracting mod package... | $cellOriginal" | Write-Log
                                Update-Window -Control StatusBarText -Property Text -Value "Extracting [$outFilePath] to [$($modItem.ModPath)]..."

                                if ($7zInstalled -eq $true) {
                                    $argumentList = @('x', ('"'+$outFilePath+'"'), ('"-o'+$modsFolderPath+'"'), '-y')
                                    Start-Process -FilePath "$7zExePath" -ArgumentList $argumentList -WindowStyle Hidden -Wait
                                } elseif ($wrarInstalled -eq $true -and $dlFileTestName -eq "rar") {
                                    $argumentList = @("x -y", ('"'+$outFilePath+'"'), ('"'+$modsFolderPath+'"'))
                                    Start-Process -FilePath "$wrarExePath" -ArgumentList $argumentList -WindowStyle Hidden -Wait
                                } else {
                                    Expand-Archive -Path $outFilePath -DestinationPath $modsFolderPath -Force -ErrorAction SilentlyContinue -ErrorVariable EXARERR
                                }
                    
                                # Verify new mod has been successfully extracted to mods folder:
                                if ((Test-Path -Path $modItem.ModPath) -eq $false) {
                                    Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                                    Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                                    ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Update failed, try again later... | $cellOriginal"
                                    "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Update failed, try again later... | $cellOriginal]" | Write-Log
                                    Update-Window -Control StatusBarText -Property Text -Value "ERROR: Mod folder [$($modItem.ModPath)] was not detected after [$dlFileTestName] archive extraction to mods folder. Please create GitHub issue."
                                    $syncHash.progressBarValue = [int](100/$syncHash.allModsUpdateTotal*$syncHash.allModsUpdateCount)
                                    Update-Window -Control ProgressBar -Property "Value" -Value $syncHash.progressBarValue
                                    $syncHash.allModsUpdateCount++
                                    Continue
                                }

                            }

                            if ($EXARERR) {
                                Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                                Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                                ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Update failed, try again later... | $cellOriginal"
                                "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Update failed, try again later... | $cellOriginal]" | Write-Log
                                Update-Window -Control StatusBarText -Property Text -Value "$EXARERR"
                                $syncHash.progressBarValue = [int](100/$syncHash.allModsUpdateTotal*$syncHash.allModsUpdateCount)
                                Update-Window -Control ProgressBar -Property "Value" -Value $syncHash.progressBarValue
                                $syncHash.allModsUpdateCount++
                                Continue
                            }
                            Update-Window -Control StatusBarText -Property Text -Value "Archive [$outFilePath] extracted..."

                            # Clean up the mod archive download from temp folder:
                            Remove-Item -Path $outFilePath -Force

                            ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Update Successful! [$(Get-Date)] | $cellOriginal"
                            "Setting [$($modDeetz.ModName)] 'Mod Name' cell text update process status to [| Update Successful! [$(Get-Date)] | $cellOriginal" | Write-Log
                            $syncHash.progressBarValue = [int](100/$syncHash.allModsUpdateTotal*$syncHash.allModsUpdateCount)
                            Update-Window -Control ProgressBar -Property "Value" -Value $syncHash.progressBarValue
                            $finalStatus = if ($syncHash.progressBarValue -eq [int32]100) {"Finsihed updating all mods! Ready..."} else {"Updating all mods. Please wait..."} #finished updating [$($modItem.modName)] mod successfully...
                            Update-Window -Control StatusBarText -Property Text -Value "$finalStatus"
                            Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
                            Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"
                            $syncHash.allModsUpdateCount++

                        }

                #############################################
                #############################################
                #endRegion UPDATE ALL MODS BUTTON LOGIC
                #############################################
                #############################################

                    })

                    $UpdateAllSelectedModsRunspaceSpawnScript.Runspace = $UpdateAllSelectedModsRunspaceSpawn
                    $data = $UpdateAllSelectedModsRunspaceSpawnScript.BeginInvoke()

                }
            })

        $UpdateAllSelectedModsRunspaceScript.Runspace = $UpdateAllSelectedModsRunspace
        $data = $UpdateAllSelectedModsRunspaceScript.BeginInvoke()

        }

        #Get-Runspace | Where-Object { $_.RunspaceAvailability -eq "Available" } | ForEach-Object Close

    })

    #############################################
    #############################################
    #endRegion UPDATE ALL MODS BUTTON
    #############################################
    #############################################

#  ██████  ███████ ██      ███████ ████████ ███████     ███████ ███████ ██      ███████  ██████ ████████ ███████ ██████      ███    ███  ██████  ██████      ██████  ██    ██ ████████ ████████  ██████  ███    ██ 
#  ██   ██ ██      ██      ██         ██    ██          ██      ██      ██      ██      ██         ██    ██      ██   ██     ████  ████ ██    ██ ██   ██     ██   ██ ██    ██    ██       ██    ██    ██ ████   ██ 
#  ██   ██ █████   ██      █████      ██    █████       ███████ █████   ██      █████   ██         ██    █████   ██   ██     ██ ████ ██ ██    ██ ██   ██     ██████  ██    ██    ██       ██    ██    ██ ██ ██  ██ 
#  ██   ██ ██      ██      ██         ██    ██               ██ ██      ██      ██      ██         ██    ██      ██   ██     ██  ██  ██ ██    ██ ██   ██     ██   ██ ██    ██    ██       ██    ██    ██ ██  ██ ██ 
#  ██████  ███████ ███████ ███████    ██    ███████     ███████ ███████ ███████ ███████  ██████    ██    ███████ ██████      ██      ██  ██████  ██████      ██████   ██████     ██       ██     ██████  ██   ████ 

    #region DELETE SELECTED MOD BUTTON
    $syncHash.DeleteSelectedMod.Add_Click({
        "Clicked 'Delete Selected Mod' button" | Write-Log

        Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"
        Update-Window -Control ProgressBar -Property "Value" -Value 0

        "Building mods list from selected cells" | Write-Log
        $selectedCells = foreach ($selectedCellRow in $syncHash.ModsListDataGrid.SelectedCells) {
            [PSCustomObject]@{
                'ModName'           = $selectedCellRow.Item.modName -replace "\|(.*)\| ",''
                'ModVersion'        = $selectedCellRow.Item.modVersion
                'ModAuthor'         = $selectedCellRow.Item.modAuthor
                'ModDescription'    = $selectedCellRow.Item.modDescription
                'ModPath'           = $selectedCellRow.Item.ModPath
                'ModWebPage'        = if ($selectedCellRow.Item.modWebLink.Length -gt 25) {$selectedCellRow.Item.modWebLink} else {"NA"}
                'ModDownloadLink'   = if ($selectedCellRow.Item.modPackageDownloadLink.Length -gt 25) {$selectedCellRow.Item.modPackageDownloadLink} else {"NA"}
            }
        }

        $selectedMods = (($selectedCells | Group-Object -Property ModName).Name) | Where-Object {$_ -cne 'Mod Name'}
        
        if (-not ($selectedMods)) {
            Update-Window -Control StatusBarText -Property Text -Value "No mod selected. Please select a mod and try again!"
        } else {
        
            "Selected mods to delete are [$($selectedMods -join ', ')]" | Write-Log
            Update-Window -Control StatusBarText -Property Text -Value "Deleting selected mods [$($selectedMods -join ', ')]..."

            $syncHash.selectedModsToDeleteList = $syncHash.allModsDeetz | Where-Object {$selectedMods -match ($_.ModName -replace '[^a-zA-Z0-9 .]','')}

            $syncHash.allModsDeleteTotal = $syncHash.selectedModsToDeleteList.ModName.Count
            $syncHash.allModsDeleteCount = 1
            foreach ($mod in $syncHash.selectedModsToDeleteList) {

                "Deleting mod [$($mod.ModName)]" | Write-Log

                if ($mod.modName -eq "Functional Weapon Pack") {
                    $CrestaWpnPckList = @(
                        '500 Magnum'
                        'AC130 Airstrike'
                        'AK-47'
                        'AWP'
                        'Black Hole'
                        'Charge Shotgun'
                        'Desert Eagle'
                        'Dragonslayer'
                        'Dual Berettas'
                        'Dual Miniguns'
                        'Exploding Star'
                        'Guided Missile'
                        'Hadouken'
                        'Holy Grenade'
                        'Laser Cutter'
                        'Lightkatana'
                        'M4A1'
                        'M249'
                        'Magic Bag'
                        'MGL'
                        'Minigun'
                        'Mjolner'
                        'Nova'
                        'P90'
                        'RPG'
                        'SCAR-20'
                        'Scorpion'
                        'SG-553'
                    )

                    $rowSearch = $mod.ModName -replace '[^a-zA-Z0-9 .]',''
                    $cellOriginal = ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName -replace "\|(.*)\| ",''
                    ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Deleting... | $cellOriginal"
                    "Setting [$($mod.ModName)] 'Mod Name' cell text update process status to [| Deleting... | $cellOriginal]" | Write-Log

                    foreach ($wpnMod in $CrestaWpnPckList) {
                        "Deleting 'Functional Weapon Pack' mod [$wpnMod]" | Write-Log
                        Remove-Item -Path "$modsFolderPath\$wpnMod" -Recurse -Force -ErrorAction SilentlyContinue

                        # Verify mod was removed from mods directory:
                        if ((Test-Path -Path "$modsFolderPath\$wpnMod") -eq $true) {
                            Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                            Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                            ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Mod deletion failed... | $cellOriginal"
                            "Setting [$($mod.ModName)] 'Mod Name' cell text update process status to [| Mod deletion failed... | $cellOriginal]" | Write-Log
                            Update-Window -Control StatusBarText -Property Text -Value "ERROR: There was a problem removing mod folder: [$($mod.ModPath)]."
                            $syncHash.progressBarValue = [int](100/$syncHash.allModsDeleteTotal*$syncHash.allModsDeleteCount)
                            Update-Window -Control ProgressBar -Property "Value" -Value $syncHash.progressBarValue
                            $syncHash.allModsDeleteCount++
                            Break
                        }

                    }

                    ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Mod deleted [$(Get-Date)]... | $cellOriginal"
                    "Setting [$($mod.ModName)] 'Mod Name' cell text update process status to [| Mod deleted [$(Get-Date)]... | $cellOriginal]" | Write-Log
                    $syncHash.progressBarValue = [int](100/$syncHash.allModsDeleteTotal*$syncHash.allModsDeleteCount)
                    Update-Window -Control ProgressBar -Property "Value" -Value $syncHash.progressBarValue
                    $finalStatus = if ($syncHash.progressBarValue -eq [int32]100) {"Finsihed deleting selected mods! Ready..."} else {"Deleting selected mods. Please wait..."} #finished updating [$($modItem.modName)] mod successfully...
                    Update-Window -Control StatusBarText -Property Text -Value "$finalStatus"
                    Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
                    Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"
                    $syncHash.allModsDeleteCount++

                } else {
                    
                    $rowSearch = $mod.ModName -replace '[^a-zA-Z0-9 .]',''
                    $cellOriginal = ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName -replace "\|(.*)\| ",''
                    ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Deleting... | $cellOriginal"
                    "Setting [$($mod.ModName)] 'Mod Name' cell text update process status to [| Deleting... | $cellOriginal]" | Write-Log
                    Remove-Item -Path $mod.ModPath -Recurse -Force -ErrorAction SilentlyContinue
        
                    # Verify mod was removed from mods directory:
                    if ((Test-Path -Path $mod.ModPath) -eq $true) {
                        Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                        ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Mod deletion failed... | $cellOriginal"
                        "Setting [$($mod.ModName)] 'Mod Name' cell text update process status to [| Mod deletion failed... | $cellOriginal]" | Write-Log
                        Update-Window -Control StatusBarText -Property Text -Value "ERROR: There was a problem removing mod folder: [$($mod.ModPath)]."
                        $syncHash.progressBarValue = [int](100/$syncHash.allModsDeleteTotal*$syncHash.allModsDeleteCount)
                        Update-Window -Control ProgressBar -Property "Value" -Value $syncHash.progressBarValue
                        $syncHash.allModsDeleteCount++
                        Continue
                    } else {
                        ($syncHash.dataTable.Rows | Where-Object {$_.ModName -match $rowSearch}).ModName = "| Mod deleted [$(Get-Date)]... | $cellOriginal"
                        "Setting [$($mod.ModName)] 'Mod Name' cell text update process status to [| Mod deleted [$(Get-Date)]... | $cellOriginal]" | Write-Log
                        $syncHash.progressBarValue = [int](100/$syncHash.allModsDeleteTotal*$syncHash.allModsDeleteCount)
                        Update-Window -Control ProgressBar -Property "Value" -Value $syncHash.progressBarValue
                        $finalStatus = if ($syncHash.progressBarValue -eq [int32]100) {"Finsihed deleting selected mods! Ready..."} else {"Deleting selected mods. Please wait..."} #finished updating [$($modItem.modName)] mod successfully...
                        Update-Window -Control StatusBarText -Property Text -Value "$finalStatus"
                        Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
                        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"
                        $syncHash.allModsDeleteCount++
                    }

                }

            }

        }

    })

    #############################################
    #############################################
    #endRegion DELETE SELECTED MOD BUTTON
    #############################################
    #############################################

#  ██████   █████   ██████ ██   ██ ██    ██ ██████       █████  ██      ██          ███    ███  ██████  ██████  ███████     ██████  ██    ██ ████████ ████████  ██████  ███    ██ 
#  ██   ██ ██   ██ ██      ██  ██  ██    ██ ██   ██     ██   ██ ██      ██          ████  ████ ██    ██ ██   ██ ██          ██   ██ ██    ██    ██       ██    ██    ██ ████   ██ 
#  ██████  ███████ ██      █████   ██    ██ ██████      ███████ ██      ██          ██ ████ ██ ██    ██ ██   ██ ███████     ██████  ██    ██    ██       ██    ██    ██ ██ ██  ██ 
#  ██   ██ ██   ██ ██      ██  ██  ██    ██ ██          ██   ██ ██      ██          ██  ██  ██ ██    ██ ██   ██      ██     ██   ██ ██    ██    ██       ██    ██    ██ ██  ██ ██ 
#  ██████  ██   ██  ██████ ██   ██  ██████  ██          ██   ██ ███████ ███████     ██      ██  ██████  ██████  ███████     ██████   ██████     ██       ██     ██████  ██   ████ 

    #region BACKUP ALL MODS BUTTON
    $syncHash.BackupAllMods.Add_MouseEnter({
        # Defines the Teardown mods folder to use throughout below logic
        $modsFolderPath = if ($syncHash.folderSelectDialog.SelectedPath) {$syncHash.folderSelectDialog.SelectedPath} else {"$env:USERPROFILE\Documents\Teardown\mods"}
        Update-Window -Control BackupAllMods -Property Tooltip -Value "Potentially time consuming, backs up all mods in [$modsFolderPath] to [$((Get-Item -Path $modsFolderPath).Parent.FullName)\mods_backup_x.zip]."
    })

    $syncHash.BackupAllMods.Add_Click({
        "Clicked 'Backup All Mods' button" | Write-Log

        # Defines the Teardown mods folder to use throughout below logic
        $modsFolderPath = if ($syncHash.folderSelectDialog.SelectedPath) {$syncHash.folderSelectDialog.SelectedPath} else {"$env:USERPROFILE\Documents\Teardown\mods"}

        Update-Window -Control ProgressBar -Property "Value" -Value 0

        Update-Window -Control ProgressBar -Property "Value" -Value 5

        $BackupAllModsRunspace = [runspacefactory]::CreateRunspace()
        $BackupAllModsRunspace.Name = "BackupAllModsButton"
        $BackupAllModsRunspace.ApartmentState = "STA"
        $BackupAllModsRunspace.ThreadOptions = "ReuseThread"
        $BackupAllModsRunspace.Open()
        $BackupAllModsRunspace.SessionStateProxy.SetVariable("syncHash", $syncHash)
        $BackupAllModsRunspace.SessionStateProxy.SetVariable("modsFolderPath", $modsFolderPath)

        $BackupAllModsRunspaceScript = [PowerShell]::Create().AddScript({

            Function Update-Window {
                Param (
                    $Control,
                    $Property,
                    $Value,
                    [switch]$AppendContent
                )
                If ($Property -eq "Close") {
                    $syncHash.Window.Dispatcher.invoke([action]{$syncHash.Window.Close()},"Normal")
                    Return
                }
                $syncHash.$Control.Dispatcher.Invoke([action]{
                    If ($PSBoundParameters['AppendContent']) {
                        $syncHash.$Control.AppendText($Value)
                    } Else {
                        $syncHash.$Control.$Property = $Value
                    }
                }, "Normal")

                if ($Control -eq 'StatusBarText' -and $Property -eq 'Text') {
                    Write-Log -Message $Value
                }

            }

            Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
            Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"

            $compress = @{
                Path = $modsFolderPath
                CompressionLevel = "Fastest"
                DestinationPath = "$((Get-Item -Path $modsFolderPath).Parent.FullName)\mods_backup_$((Get-Date).ToFileTime()).zip"
            }

            Update-Window -Control ProgressBar -Property "Value" -Value 28

            Update-Window -Control StatusBarText -Property Text -Value "Please wait... backing up mods directory [$($compress.Path)] to [$($compress.DestinationPath)]"

            Update-Window -Control ProgressBar -Property "Value" -Value 36

            $backup = Compress-Archive @compress -Force -ErrorAction SilentlyContinue -ErrorVariable BACKUPERR

            if ($BACKUPERR) {
                "ERROR: There was a problem backing up mods folder [$($compress.Path)] to [$($compress.DestinationPath)]. $BACKUPERR" | Write-Log
                Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                Update-Window -Control StatusBarText -Property Text -Value "ERROR: There was a problem backing up mods folder [$($compress.Path)] to [$($compress.DestinationPath)]. $BACKUPERR"
            } else {
                Update-Window -Control ProgressBar -Property "Value" -Value 89
                Update-Window -Control StatusBarText -Property Text -Value "Finished backing up mods directory! [$($compress.Path)] to [$($compress.DestinationPath)]"
                Update-Window -Control ProgressBar -Property "Value" -Value 100
            }

        })

        $BackupAllModsRunspaceScript.Runspace = $BackupAllModsRunspace
        $data = $BackupAllModsRunspaceScript.BeginInvoke()

    })

    #############################################
    #############################################
    #endRegion BACKUP ALL MODS BUTTON
    #############################################
    #############################################

#  ███████ ██   ██ ██████   ██████  ██████  ████████     ██       ██████   ██████  ███████     ██████  ██    ██ ████████ ████████  ██████  ███    ██ 
#  ██       ██ ██  ██   ██ ██    ██ ██   ██    ██        ██      ██    ██ ██       ██          ██   ██ ██    ██    ██       ██    ██    ██ ████   ██ 
#  █████     ███   ██████  ██    ██ ██████     ██        ██      ██    ██ ██   ███ ███████     ██████  ██    ██    ██       ██    ██    ██ ██ ██  ██ 
#  ██       ██ ██  ██      ██    ██ ██   ██    ██        ██      ██    ██ ██    ██      ██     ██   ██ ██    ██    ██       ██    ██    ██ ██  ██ ██ 
#  ███████ ██   ██ ██       ██████  ██   ██    ██        ███████  ██████   ██████  ███████     ██████   ██████     ██       ██     ██████  ██   ████ 

    #region EXPORT LOGS BUTTON
    $syncHash.ExportLogsButton.Add_Click({
        "Clicked 'Export Logs' button" | Write-Log

        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

        Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"
        Update-Window -Control StatusBarText -Property Text -Value "Exporting log..."

        $SaveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $SaveDialog.InitialDirectory = "$ENV:USERPROFILE\Desktop"
        $SaveDialog.Filter = "LOG Files (*.log)|*.log|TEXT Files (*.txt)|*.txt|All files (*.*)|*.*"
        $SaveDialog.ShowDialog() | Out-Null
        $syncHash.tmmLog >> $SaveDialog.Filename
        if ($SaveDialog.Filename) {
            [System.Windows.Forms.MessageBox]::Show("Logs exported at $($SaveDialog.Filename)","Log Export | Teardown Mods Manager v2.1.0")
            Update-Window -Control StatusBarText -Property Text -Value "Logs exported at $($SaveDialog.Filename)"
        } else {
            "Log export cancelled" | Write-Log
            Update-Window -Control StatusBarText -Property Text -Value "Log export cancelled. Ready..."
        }

    })

    #############################################
    #############################################
    #endRegion EXPORT LOGS BUTTON
    #############################################
    #############################################

#  ███████ ███████ ██      ███████  ██████ ████████     ██████  ███████ ███████  █████  ██    ██ ██   ████████     ███    ███  ██████  ██████  ███████     ██       ██████   ██████  █████  ████████ ██  ██████  ███    ██     ████████ ███████ ██   ██ ████████ ██████   ██████  ██   ██ 
#  ██      ██      ██      ██      ██         ██        ██   ██ ██      ██      ██   ██ ██    ██ ██      ██        ████  ████ ██    ██ ██   ██ ██          ██      ██    ██ ██      ██   ██    ██    ██ ██    ██ ████   ██        ██    ██       ██ ██     ██    ██   ██ ██    ██  ██ ██  
#  ███████ █████   ██      █████   ██         ██        ██   ██ █████   █████   ███████ ██    ██ ██      ██        ██ ████ ██ ██    ██ ██   ██ ███████     ██      ██    ██ ██      ███████    ██    ██ ██    ██ ██ ██  ██        ██    █████     ███      ██    ██████  ██    ██   ███   
#       ██ ██      ██      ██      ██         ██        ██   ██ ██      ██      ██   ██ ██    ██ ██      ██        ██  ██  ██ ██    ██ ██   ██      ██     ██      ██    ██ ██      ██   ██    ██    ██ ██    ██ ██  ██ ██        ██    ██       ██ ██     ██    ██   ██ ██    ██  ██ ██  
#  ███████ ███████ ███████ ███████  ██████    ██        ██████  ███████ ██      ██   ██  ██████  ███████ ██        ██      ██  ██████  ██████  ███████     ███████  ██████   ██████ ██   ██    ██    ██  ██████  ██   ████        ██    ███████ ██   ██    ██    ██████   ██████  ██   ██ 

    #region SELECT DEFAULT MODS LOCATION TEXTBOX
    $syncHash.SelectDefaultModsLocation.Add_PreviewMouseUp({
        "Clicked 'Select Default Mods Location' textbox" | Write-Log

        Update-Window -Control ProgressBar -Property "Value" -Value 0
        Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"
        Update-Window -Control StatusBarText -Property "Text" -Value "Opening 'Select Default Mods Location' folder selection window..."

        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

        $syncHash.folderSelectDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $syncHash.folderSelectDialog.Description = "Select your Teardown mods folder:"
        $syncHash.folderSelectDialog.RootFolder = "MyComputer"
        $syncHash.folderSelectDialog.ShowDialog() | Out-Null

        if ($syncHash.folderSelectDialog.SelectedPath.Length -gt 2) {
            Update-Window -Control SelectDefaultModsLocation -Property Text -Value "$($syncHash.folderSelectDialog.SelectedPath)"
            Update-Window -Control StatusBarText -Property Text -Value "Selected Teardown mods folder: [$($syncHash.folderSelectDialog.SelectedPath)]. Ready..."

            "Invoking mod table layout and prep" | Write-Log
            Invoke-TablePrep
    
            "Getting mod file details" | Write-Log
            $syncHash.allModsDeetz = Get-ModDeets -ModDir $syncHash.folderSelectDialog.SelectedPath

            foreach ($modItem in $syncHash.allModsDeetz) {
                "Refreshing mod row [$($modItem.ModName)]" | Write-Log
        
                $row = $syncHash.dataTable.NewRow()
        
                    $row.ModName            = ($modItem.ModName -replace '[^a-zA-Z0-9 .]','')
                    $row.ModVersion         = $modItem.ModVersion
                    $row.ModAuthor          = $modItem.ModAuthor
                    $row.ModDescription     = $modItem.ModDescription
                    $row.ModPath            = $modItem.ModPath
                    $row.ModWebpage         = $modItem.ModWebPage
                    $row.ModDownloadLink    = $modItem.ModDownloadLink
        
                [void]$syncHash.dataTable.Rows.Add($row)
            }
            
            Update-Window -Control StatusBarText -Property Text -Value "Finished reloading new mod list [$($syncHash.folderSelectDialog.SelectedPath)]. Ready..."
        } else {
            Update-Window -Control StatusBarText -Property Text -Value "Folder selection cancelled. Ready..."
        }

    })

    #############################################
    #############################################
    #endRegion SELECT DEFAULT MODS LOCATION TEXTBOX
    #############################################
    #############################################

    [Void]$syncHash.Window.ShowDialog()
    $syncHash.Error = $Error
    $manWindowRunspace.Close()
    $manWindowRunspace.Dispose()
    $BackupAllModsRunspace.Close()
    $BackupAllModsRunspace.Dispose()
    #Get-Runspace | Where-Object { $_.RunspaceAvailability -eq "Available" } | ForEach-Object Close
})

$manWindowRunspaceScript.Runspace = $manWindowRunspace
[void]$manWindowRunspaceScript.BeginInvoke()

#############################################
#############################################
#endRegion MAIN WINDOW
#############################################
#############################################
