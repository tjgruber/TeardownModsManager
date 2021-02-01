<# TeardownModsManager | by Timothy Gruber

Designed and written by Timothy Gruber:
    https://timothygruber.com
    https://github.com/tjgruber/TeardownModsManager

#>

#region Run script as elevated admin and unrestricted executionpolicy
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID)
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
if ($myWindowsPrincipal.IsInRole($adminRole)) {
    $Host.UI.RawUI.WindowTitle = "Teardown Mods Manager | by Timothy Gruber"
    $Host.UI.RawUI.BackgroundColor = "DarkBlue"
    Clear-Host
} else {
    Start-Process PowerShell.exe -ArgumentList "-ExecutionPolicy Unrestricted -NoExit $($script:MyInvocation.MyCommand.Path)" -Verb RunAs
    Exit
}
#endregion

Write-Host "Running Teardown Mods Manager | by Timothy Gruber...`n`nClosing this window will close Teardown Mods Manager.`n"

#############################################
#############################################
#region MAIN WINDOW
#############################################
#############################################

$syncHash = [hashtable]::Synchronized(@{})
$manWindowRunspace = [runspacefactory]::CreateRunspace()
$manWindowRunspace.Name = "MainWindow"
$manWindowRunspace.ApartmentState = "STA"
$manWindowRunspace.ThreadOptions = "ReuseThread"
$manWindowRunspace.Open()
$manWindowRunspace.SessionStateProxy.SetVariable("syncHash", $syncHash)
$manWindowRunspaceScript = [PowerShell]::Create().AddScript({

    Add-Type -AssemblyName PresentationFramework

    #############################################
    #############################################
    #region FUNCTIONS
    #############################################
    #############################################

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
            [String]$ModDir
        )

        if (-not $ModDir) {
            if ($true -eq (Test-Path -Path "$env:USERPROFILE\Documents\Teardown\mods" -PathType Container)) {
                $ModDir = "$env:USERPROFILE\Documents\Teardown\mods"
            } else {
                #Write-Warning "Default mods location [$env:USERPROFILE\Documents\Teardown\mods] does not exist. Please specify a mod directory with [-ModDir ""path\to\mod(s)""]"
            }
        } else {
            if ($true -eq (Test-Path -Path $ModDir -PathType Container)) {
                $ModDir = $ModDir
            }
        }

        if ($ModDir -match "Teardown\\mods$") {
            $allMods = Get-ChildItem -Path $modDir -Directory
        } else {
            $allMods = Get-Item -Path $modDir
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
            $modName        = if (($modInfo -match 'name = ' -split 'name = ')[1].Length -gt 2) {($modInfo -match 'name = ' -split 'name = ')[1] -replace "_",' '} else {"modName not found"}
            $modVersion     = if (($modInfo -match 'version = ' -split 'version = ')[1].Length -gt 2) {($modInfo -match 'version = ' -split 'version = ')[1] -replace "_",' '} else {"version not found in mod info.txt"}
            $modAuthor      = if (($modInfo -match 'author = ' -split 'author = ')[1].Length -gt 2) {($modInfo -match 'author = ' -split 'author = ')[1]} else {"modAuthor not found"}
            $modDescription = if (($modInfo -match 'description = ' -split 'description = ')[1].Length -gt 2) {($modInfo -match 'description = ' -split 'description = ')[1]} else {"modDescription not found"}
            # MyCresta Check
                if (($modAuthor -match "My Cresta") -and ($mod -ne $crestaMod)) {
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
    Title="Teardown Mods Manager v1.0.1 | by Timothy Gruber" Height="500" Width="958" ScrollViewer.VerticalScrollBarVisibility="Disabled" MinWidth="924" MinHeight="500">
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
                    <Button Name="SignInButton" Content="Sign-in" MinWidth="80" />
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
                                <Button DockPanel.Dock="Left" Name="UpdateSelectedMod" Content="Update Selected Mod" VerticalAlignment="Center" Height="30" Width="200" FontSize="14" Padding="10,1" Margin="5,0" HorizontalAlignment="Right" FontWeight="Bold"/>
                                <Button DockPanel.Dock="Left" Name="UpdateAllMods" Content="Update All Mods" VerticalAlignment="Center" Height="30" Width="200" FontSize="14" Padding="10,1" Margin="5,0" HorizontalAlignment="Right" FontWeight="Bold"/>
                                <StackPanel DockPanel.Dock="Left" HorizontalAlignment="Left" Margin="20,0,5,0">
                                </StackPanel>
                            </DockPanel>
                            <GroupBox Name="ModsListBoxGroupBox" Header="Installed Mods List" Margin="0,2,0,0">
                                <DataGrid DockPanel.Dock="Top" Name="ModsListDataGrid" HorizontalScrollBarVisibility="Visible" SelectionMode="Single" HeadersVisibility="None" Visibility="Hidden">
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
                                <TextBlock TextWrapping="Wrap" FontWeight="Normal"><Run FontWeight="Bold" Text="Created by: "/><Run Text="&#x9;Timothy Gruber&#xA;"/><Run FontWeight="Bold" Text="Website:&#x9;"/><Hyperlink NavigateUri="https://timothygruber.com/"><Run Text="TimothyGruber.com&#xA;"/></Hyperlink><Run FontWeight="Bold" Text="GitHub:&#x9;&#x9;"/><Hyperlink NavigateUri="https://github.com/tjgruber/TeardownModsManager"><Run Text="https://github.com/tjgruber/TeardownModsManager&#xA;"/></Hyperlink><Run FontWeight="Bold" Text="Version:"/><Run Text="&#x9;&#x9;v1.0.1-alpha"/></TextBlock>
                            </ScrollViewer>
                        </GroupBox>
                        <GroupBox Header="Help Menu:" FontWeight="Bold" FontSize="14">
                            <TabControl TabStripPlacement="Left">
                                <TabItem Header="General" Height="35" TextOptions.TextFormattingMode="Display" VerticalAlignment="Top" HorizontalContentAlignment="Stretch" FontSize="14">
                                    <GroupBox Header="General..." FontSize="16">
                                        <ScrollViewer HorizontalScrollBarVisibility="Auto">
                                            <TextBlock  TextWrapping="Wrap" FontWeight="Normal"><Run FontWeight="Normal" FontSize="14" Text="This script can be used to update, backup, and remove installed Teardown mods until until Steam Workshop availability in Teardown 0.6."/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text=""/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text="This is a work in progress, and not all mods will work due to mod names not being consistent between teardownmods.com, mod name in info.txt, mod folder name, .zip not being used, mod packages containing multiple mods, etc. If a mod does not work, create a GitHub issue to let me know, and I'll see about writing a static code workaround for that mod to get it to work!"/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text=""/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text="All mods are checked against teardownmods.com"/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text=""/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text="The sign-in button is not functional, but the idea behind it was ability to sign-in to the site allow you to do more. Likely, will not get to it before TD 0.6."/></TextBlock>
                                        </ScrollViewer>
                                    </GroupBox>
                                </TabItem>
                                <TabItem Header="Installed Mods Tab" Height="35" VerticalAlignment="Top" TextOptions.TextFormattingMode="Display" FontSize="14">
                                    <GroupBox Header="Installed Mods Tab..." FontSize="16">
                                        <ScrollViewer HorizontalScrollBarVisibility="Auto">
                                            <TextBlock ><Run FontWeight="Normal" FontSize="14" Text="    1.  For now, this script only works if mods are in default location."/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text="    2.  Make sure to back up your mods location. By default, this is your 'Documents\Teardown\mods' folder. Do this manually until I implement this function."/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text="    3.  When a mod developer fixes naming consistency of a mod that was prevously inconsistent, you may get an error saying the mod could not be found after extraction. This is expected. Try reloading mod list, and trying again, as the error is correct, but it still likely updated just fine."/></TextBlock>
                                        </ScrollViewer>
                                    </GroupBox>
                                </TabItem>
                                <TabItem Header="Mod Compatibility" Height="35" VerticalAlignment="Top" TextOptions.TextFormattingMode="Display" FontSize="14">
                                    <GroupBox Header="Mod devs: to help ensure mod compatibility with Teardown Mods Manager..." FontSize="16">
                                        <ScrollViewer HorizontalScrollBarVisibility="Auto">
                                            <TextBlock ><Run FontWeight="Normal" FontSize="14" Text="    1.  Mod name consistency is the biggest factor in your mod working with this app."/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text="    2.  Using a .zip archive is second biggest factor, until I feel like implementing other support."/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text="    3.  Ensure mod 'name = ' in mod info.txt matches the name of your mod at teardownmods.com."/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text="    4.  Ensure mod name matches folder name, i.e. 'Documents\Teardown\mods\mod name'."/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text="    5.  Ensure 'version = ' in mod info.txt is current released version at teardownmods.com. Something meaningful to the most amount of people, such as '2021.01.31.x' or '1.5.2' for example."/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text="    6.  Ensure the last file in the downloads list at teardownmods.com for the mod is the regular default mod and is a .zip file."/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text="    7.  Ensure name of mod folder is zipped: so extracting to Teardown\mods will result in Teardown\mods\modName"/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text="    8.  Instead of having multiple mods/maps, use mod options to control lighting, time of day, weather, etc."/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text="    9.  Try to package mods together in the same mod folder that are part of the same mod package. That way I don't have to hard code a workaround."/></TextBlock>
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

    #############################################
    #############################################
    #region ONLOAD CODE
    #############################################
    #############################################

    Invoke-TablePrep

    $syncHash.allModsDeetz = Get-ModDeets

    foreach ($modItem in $syncHash.allModsDeetz) {

        $row = $syncHash.dataTable.NewRow()

            $row.ModName            = $modItem.ModName
            $row.ModVersion         = $modItem.ModVersion
            $row.ModAuthor          = $modItem.ModAuthor
            $row.ModDescription     = $modItem.ModDescription
            $row.ModPath            = $modItem.ModPath
            $row.ModWebpage         = $modItem.ModWebPage
            $row.ModDownloadLink    = $modItem.ModDownloadLink

        [void]$syncHash.dataTable.Rows.Add($row)
    }

    #############################################
    #############################################
    #endRegion ONLOAD CODE
    #############################################
    #############################################

    #############################################
    #############################################
    #region UPDATE SELECTED MOD BUTTON
    #############################################
    #############################################

    $syncHash.UpdateSelectedMod.Add_Click({

        Update-Window -Control ProgressBar -Property "Value" -Value 0
        Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"

        if (-not ($syncHash.ModsListDataGrid.SelectedCells | Select-Object -First 1).Item) {
            Update-Window -Control StatusBarText -Property Text -Value "No mod selected. Please select a mod and try again!"
        }

        $UpdateSelectedModRunspace = [runspacefactory]::CreateRunspace()
        $UpdateSelectedModRunspace.Name = "UpdateSelectedModButton"
        $UpdateSelectedModRunspace.ApartmentState = "STA"
        $UpdateSelectedModRunspace.ThreadOptions = "ReuseThread"
        $UpdateSelectedModRunspace.Open()
        $UpdateSelectedModRunspace.SessionStateProxy.SetVariable("syncHash", $syncHash)

        $UpdateSelectedModRunspaceScript = [PowerShell]::Create().AddScript({

            #############################################
            #region FUNCTIONS
            #############################################

            function Get-ModData {
                [CmdletBinding()]
                param (
                    [String]$ModDir,
                    $allMods
                )
                
                begin {}
                
                process {

                    $allModsData = foreach ($mod in $allMods) {
                        Update-Window -Control ProgressBar -Property "Value" -Value 12
                        $modSearchName = $mod.modSearchName
                        $modName = $mod.ModName
                        $modVersion = $mod.ModVersion
                        $modAuthor = $mod.ModAuthor
                        $modDescription = $mod.ModDescription
                        $modSearchURI = "https://teardownmods.com/index.php?/search/&q=" + ($modSearchName -replace " ",'%20' -replace "_",'%20' -replace "'s",'') + "&search_and_or=or&sortby=relevancy"
                        #Write-Host "`tSearching teardownmods.com for mod at: [$modSearchURI]"
                        Update-Window -Control StatusBarText -Property Text -Value "Searching teardownmods.com for [$modName]..."
                        $modSearchResults = Invoke-WebRequest $modSearchURI -UseBasicParsing -ErrorAction SilentlyContinue
                        Update-Window -Control ProgressBar -Property "Value" -Value 25
                        $modWebLink = ($modSearchResults.Links | Where-Object {$_.outerHTML -match $modSearchName -and $_.href -match "getNewComment"} | Select-Object -First 1).href -replace '&amp;','&'
                        if (-not $modWebLink) {
                            $modSearchNameSplit = $modName -split " "
                            $modSearchName = $modSearchNameSplit[0] -replace "'s",''
                            $modSearchURI = "https://teardownmods.com/index.php?/search/&q=" + ($modSearchName -replace " ",'%20' -replace "_",'%20' -replace "'s",'') + "&search_and_or=or&sortby=relevancy"
                            #Write-Host "`tSearching teardownmods.com for mod at: [$modSearchURI]"
                            $modSearchResults = Invoke-WebRequest $modSearchURI -UseBasicParsing -ErrorAction SilentlyContinue
                            $modWebLink = ($modSearchResults.Links | Where-Object {$_.outerHTML -match $modSearchName -and $_.href -match "getNewComment"} | Select-Object -First 1).href -replace '&amp;','&'
                        }
                        if (-not $modWebLink) {
                            if ($modName -match "vechicles") {
                                $modSearchName = 'Every vechicle'
                                $modSearchURI = "https://teardownmods.com/index.php?/search/&q=" + ($modSearchName -replace " ",'%20' -replace "_",'%20' -replace "'s",'') + "&search_and_or=or&sortby=relevancy"
                                #Write-Host "`tSearching teardownmods.com for mod at: [$modSearchURI]"
                                $modSearchResults = Invoke-WebRequest $modSearchURI -UseBasicParsing -ErrorAction SilentlyContinue
                                $modWebLink = ($modSearchResults.Links | Where-Object {$_.outerHTML -match $modSearchName -and $_.href -match "getNewComment"} | Select-Object -First 1).href -replace '&amp;','&'
                            }
                        }

                        Update-Window -Control ProgressBar -Property "Value" -Value 40
                    
                        if ($modWebLink) {
                            #Write-Host "`tAccessing mod web page at teardownmods.com at: [$modWebLink]"
                            $modWebPage = Invoke-WebRequest -Uri $modWebLink -SessionVariable mwp -UseBasicParsing -ErrorAction SilentlyContinue
                            $syncHash.mwp = $mwp
                            $modDownloadLink = ($modWebPage.Links | Where-Object {$_ -match '&amp;do=download&amp;csrfKey='} | Select-Object -First 1).href -replace '&amp;','&'
                            #Write-Host "`tAccessing mod download page at teardownmods.com at: [$modDownloadLink]"
                            Update-Window -Control StatusBarText -Property Text -Value "Accessing [$modName] mod download page at teardownmods.com..."
                            $modPackageDownloadPage = Invoke-WebRequest -Uri $modDownloadLink -Method Get -WebSession $syncHash.mwp -UseBasicParsing -ErrorAction SilentlyContinue
                            $modPackageDownloadLink = ($modPackageDownloadPage.Links | Where-Object {$_.'data-action' -eq 'download'} | Select-Object -Last 1).href -replace '&amp;','&'
                            #Write-Host "`tAssuming mod package download link at teardownmods.com is: [$modPackageDownloadLink]"
                            Update-Window -Control StatusBarText -Property Text -Value "Assuming [$modName] mod package download link at teardownmods.com..."
                        } else {
                            #Write-Warning "Mod [$modName] not found in teardownmods.com search results!"
                        }
                    
                        [PSCustomObject]@{
                            'ModName'           = $modName
                            'ModVersion'        = $modVersion
                            'ModAuthor'         = $modAuthor
                            'ModDescription'    = $modDescription
                            'ModPath'           = $mod.ModPath
                            'ModWebPage'        = if ($modWebLink.Length -gt 25) {$modWebLink} else {"Not Found"}
                            'ModDownloadLink'   = if ($modPackageDownloadLink.Length -gt 25) {$modPackageDownloadLink} else {"Not Found"}
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
            }

            #############################################
            #endRegion FUNCTIONS
            #############################################

            #############################################
            #############################################
            #region UPDATE SELECTED MOD BUTTON LOGIC
            #############################################
            #############################################

            #$allModsData = Get-ModData -allMods ($syncHash.allModsDeetz | Select-Object -First 3)
            $allModsData = Get-ModData -allMods ($syncHash.allModsDeetz | Where-Object -Property ModName -EQ (($syncHash.ModsListDataGrid.SelectedCells | Select-Object -First 1).Item.ModName))

            foreach ($modItem in $allModsData) {

                ($syncHash.dataTable.Rows | Where-Object {$_.ModName -eq $modItem.modName}).ModWebPage = $modItem.ModWebPage
                ($syncHash.dataTable.Rows | Where-Object {$_.ModName -eq $modItem.modName}).ModDownloadLink = $modItem.ModDownloadLink

                Update-Window -Control StatusBarText -Property Text -Value "Retrieving [$($modItem.modName)] mod download info..."

                Update-Window -Control ProgressBar -Property "Value" -Value 50

                $outFile = "$($modItem.modName).zip"
                $newDir = New-Item -Path "$env:TEMP\TeardownMods" -ItemType Directory -Force
                $outFilePath = "$env:TEMP\TeardownMods\$outFile"
                Update-Window -Control ProgressBar -Property "Value" -Value 60
                Update-Window -Control StatusBarText -Property Text -Value "Downloading [$($modItem.modName)] mod..."
                Invoke-WebRequest -Uri $modItem.ModDownloadLink -OutFile $outFilePath -WebSession $syncHash.mwp -UseBasicParsing -ErrorAction SilentlyContinue -ErrorVariable DLERR

                if (-not (Test-Path -Path $outFilePath -PathType Leaf)) {
                    Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                    Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                    Update-Window -Control StatusBarText -Property Text -Value "ERROR: There was a problem downloading mod: [$($modItem.modName)], from URL: [$($modItem.ModDownloadLink)], to local file path: [$($outFilePath)]. Please submit this in a GitHub issue."
                    Break
                }

                Update-Window -Control StatusBarText -Property Text -Value "[$($modItem.modName)] mod package download finished..."
                Update-Window -Control ProgressBar -Property "Value" -Value 75

                Update-Window -Control StatusBarText -Property Text -Value "Removing old version of [$($modItem.modName)] mod..."

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

                        Remove-Item -Path "$env:USERPROFILE\Documents\Teardown\mods\$wpnMod" -Recurse -Force

                        # Verify old version of mod was removed from mods directory:
                        if ((Test-Path -Path "$env:USERPROFILE\Documents\Teardown\mods\$wpnMod") -eq $true) {
                            Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                            Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                            Update-Window -Control StatusBarText -Property Text -Value "ERROR: There was a problem removing old mod version folder: [$("$env:USERPROFILE\Documents\Teardown\mods\$wpnMod")]."
                            Break
                        }

                    }

                    Update-Window -Control StatusBarText -Property Text -Value "Extracting [$outFilePath] to [$("$env:USERPROFILE\Documents\Teardown\mods\")]..."

                    Expand-Archive -Path $outFilePath -DestinationPath "$env:USERPROFILE\Documents\Teardown\mods" -Force -ErrorAction SilentlyContinue -ErrorVariable EXARERR

                    foreach ($wpnMod in $CrestaWpnPckList) {

                        # Verify new mod has been successfully extracted to mods folder:
                        if ((Test-Path -Path "$env:USERPROFILE\Documents\Teardown\mods\$wpnMod") -eq $false) {
                            Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                            Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                            Update-Window -Control StatusBarText -Property Text -Value "ERROR: Mod folder [$("$env:USERPROFILE\Documents\Teardown\mods\$wpnMod")] was not detected after zip archive extraction to mods folder. Please create GitHub issue."
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
                        Break
                    }

                    Update-Window -Control StatusBarText -Property Text -Value "Extracting [$outFilePath] to [$($modItem.ModPath)]..."
                
                    Expand-Archive -Path $outFilePath -DestinationPath "$env:USERPROFILE\Documents\Teardown\mods" -Force -ErrorAction SilentlyContinue -ErrorVariable EXARERR
                    # Verify new mod has been successfully extracted to mods folder:
                    if ((Test-Path -Path $modItem.ModPath) -eq $false) {
                        Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                        Update-Window -Control StatusBarText -Property Text -Value "ERROR: Mod folder [$($modItem.ModPath)] was not detected after zip archive extraction to mods folder. Please create GitHub issue."
                        Break
                    }

                }

                Update-Window -Control ProgressBar -Property "Value" -Value 87

                if ($EXARERR) {
                    Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                    Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                    Update-Window -Control StatusBarText -Property Text -Value "$EXARERR"
                    Break
                }

                Update-Window -Control StatusBarText -Property Text -Value "Zip archive extracted..."

                # Clean up the mod archive download from temp folder:
                Remove-Item -Path $outFilePath -Force

                Update-Window -Control ProgressBar -Property "Value" -Value 100
                Update-Window -Control StatusBarText -Property Text -Value "[$($modItem.modName)] mod update finished successfully! Ready..."

            }

            #############################################
            #############################################
            #endRegion UPDATE SELECTED MOD BUTTON LOGIC
            #############################################
            #############################################

        })

        $UpdateSelectedModRunspaceScript.Runspace = $UpdateSelectedModRunspace
        $data = $UpdateSelectedModRunspaceScript.BeginInvoke()

    })

    #############################################
    #############################################
    #endRegion UPDATE SELECTED MOD BUTTON
    #############################################
    #############################################

    #############################################
    #############################################
    #region RELOAD MOD LIST BUTTON
    #############################################
    #############################################

    $syncHash.ReloadModList.Add_Click({

        Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"

        $syncHash.ModsListDataGrid.Visibility = "Hidden"

        Invoke-TablePrep

        $syncHash.allModsDeetz = Get-ModDeets
    
        foreach ($modItem in $syncHash.allModsDeetz) {
    
            $row = $syncHash.dataTable.NewRow()
    
                $row.ModName            = $modItem.ModName
                $row.ModVersion         = $modItem.ModVersion
                $row.ModAuthor          = $modItem.ModAuthor
                $row.ModDescription     = $modItem.ModDescription
                $row.ModPath            = $modItem.ModPath
                $row.ModWebpage         = $modItem.ModWebPage
                $row.ModDownloadLink    = $modItem.ModDownloadLink
    
            [void]$syncHash.dataTable.Rows.Add($row)
        }

        Update-Window -Control ProgressBar -Property "Value" -Value 0
        Update-Window -Control StatusBarText -Property Text -Value "Mod list refreshed. Ready..."

    })

    #############################################
    #############################################
    #endRegion RELOAD MOD LIST BUTTON
    #############################################
    #############################################

    #############################################
    #############################################
    #region UPDATE ALL MODS BUTTON
    #############################################
    #############################################

    $syncHash.UpdateAllMods.Add_Click({

        Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"

        Update-Window -Control StatusBarText -Property Text -Value "This button is not yet functional. Ready..."

    })

    #############################################
    #############################################
    #endRegion UPDATE ALL MODS BUTTON
    #############################################
    #############################################

    #############################################
    #############################################
    #region DELETE SELECTED MOD BUTTON
    #############################################
    #############################################

    $syncHash.DeleteSelectedMod.Add_Click({

        Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"

        Update-Window -Control StatusBarText -Property Text -Value "This button is not yet functional. Ready..."

    })

    #############################################
    #############################################
    #endRegion DELETE SELECTED MOD BUTTON
    #############################################
    #############################################

    #############################################
    #############################################
    #region BACKUP ALL MODS BUTTON
    #############################################
    #############################################

    $syncHash.BackupAllMods.Add_Click({

        Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"

        Update-Window -Control StatusBarText -Property Text -Value "This button is not yet functional. Ready..."

    })

    #############################################
    #############################################
    #endRegion BACKUP ALL MODS BUTTON
    #############################################
    #############################################

    #############################################
    #############################################
    #region SIGN-IN BUTTON
    #############################################
    #############################################

    $syncHash.SignInButton.Add_Click({

        Update-Window -Control ProgressBar -Property "Background" -Value "#FFE6E6E6"
        Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF06B025"

        Update-Window -Control StatusBarText -Property Text -Value "This button is not yet functional. Ready..."

    })

    #############################################
    #############################################
    #endRegion SIGN-IN BUTTON
    #############################################
    #############################################

    [Void]$syncHash.Window.ShowDialog()
    $syncHash.Error = $Error
    $manWindowRunspace.Close()
    $manWindowRunspace.Dispose()
    $UpdateSelectedModRunspace.Close()
    $UpdateSelectedModRunspace.Dispose()
})

$manWindowRunspaceScript.Runspace = $manWindowRunspace
[void]$manWindowRunspaceScript.BeginInvoke()

#############################################
#############################################
#endRegion MAIN WINDOW
#############################################
#############################################
