
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
                $modDescription = "27 Different Fully Working Weapons"
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
    Title="Teardown Mods Manager v2021.01.31.1 | by Timothy Gruber" Height="500" Width="958" ScrollViewer.VerticalScrollBarVisibility="Disabled" MinWidth="924" MinHeight="500">
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
                                <TextBlock TextWrapping="Wrap" FontWeight="Normal"><Run FontWeight="Bold" Text="Created by: "/><Run Text="&#x9;Timothy Gruber&#xA;"/><Run FontWeight="Bold" Text="Website:&#x9;"/><Hyperlink NavigateUri="https://timothygruber.com/"><Run Text="TimothyGruber.com&#xA;"/></Hyperlink><Run FontWeight="Bold" Text="GitHub:&#x9;&#x9;"/><Hyperlink NavigateUri="https://github.com/tjgruber/TeardownModsManager"><Run Text="https://github.com/tjgruber/TeardownModsManager&#xA;"/></Hyperlink><Run FontWeight="Bold" Text="Version:"/><Run Text="&#x9;&#x9;2021.01.31.1"/></TextBlock>
                            </ScrollViewer>
                        </GroupBox>
                        <GroupBox Header="Help Menu:" FontWeight="Bold" FontSize="14">
                            <TabControl TabStripPlacement="Left">
                                <TabItem Header="General" Height="35" TextOptions.TextFormattingMode="Display" VerticalAlignment="Top" HorizontalContentAlignment="Stretch" FontSize="14">
                                    <GroupBox Header="General..." FontSize="16">
                                        <ScrollViewer>
                                            <TextBlock  TextWrapping="Wrap" FontWeight="Normal"><Run FontWeight="Normal" Text="This script is used to manage installed Teardown mods."/><LineBreak/><Run FontWeight="Normal"/><LineBreak/><Run FontWeight="Normal" Text="All mods are checked against teardownmods.com"/><LineBreak/><Run FontWeight="Normal"/><LineBreak/><Run FontWeight="Normal" Text="The sign-in button is not yet functional."/></TextBlock>
                                        </ScrollViewer>
                                    </GroupBox>
                                </TabItem>
                                <TabItem Header="Installed Mods Tab" Height="35" VerticalAlignment="Top" TextOptions.TextFormattingMode="Display" FontSize="14">
                                    <GroupBox Header="Installed Mods Tab..." FontSize="16">
                                        <ScrollViewer>
                                            <TextBlock ><Run FontWeight="Normal" Text="    1.  For now, this script only works if mods are in default location."/></TextBlock>
                                        </ScrollViewer>
                                    </GroupBox>
                                </TabItem>
                                <TabItem Header="Mod Compatibility" Height="35" VerticalAlignment="Top" TextOptions.TextFormattingMode="Display" FontSize="14">
                                    <GroupBox Header="Mod devs: to help ensure mod compatibility with Teardown Mods Manager..." FontSize="16">
                                        <ScrollViewer>
                                            <TextBlock ><Run FontWeight="Normal" FontSize="14" Text="    1.  Ensure mod 'name = ' in mod info.txt matches the name of your mod at teardownmods.com."/><LineBreak/><Run FontWeight="Normal" FontSize="14" Text="    2.  Ensure mod name matches folder name, i.e. 'Documents\Teardown\mods\folder name'."/></TextBlock>
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

        if (-not ($syncHash.ModsListDataGrid.SelectedCells | Select-Object -First 1).Item) {
            Update-Window -Control StatusBarText -Property Text -Value "No mod selected. Please select a mod and try again!"
        }

        $UpdateSelectedModRunspace = [runspacefactory]::CreateRunspace()
        $UpdateSelectedModRunspace.Name = "SignInWindow"
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

                Update-Window -Control ProgressBar -Property "Value" -Value 87

                if ($EXARERR) {
                    Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
                    Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
                    Update-Window -Control StatusBarText -Property Text -Value "$EXARERR"
                    Break
                }

                Update-Window -Control StatusBarText -Property Text -Value "Zip archive extracted..."

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


    [Void]$syncHash.Window.ShowDialog()
    $syncHash.Error = $Error
})

$manWindowRunspaceScript.Runspace = $manWindowRunspace
[void]$manWindowRunspaceScript.BeginInvoke()

#############################################
#############################################
#endRegion MAIN WINDOW
#############################################
#############################################

<# notes
Update-Window -Control ProgressBar -Property "Background" -Value "#FFEA8A00"
Update-Window -Control ProgressBar -Property "Foreground" -Value "#FF0000"
Update-Window -Control ProgressBar -Property "Value" -Value 50
$test = $syncHash.dataTable | Where-Object -Property 'Mod Name' -EQ "Downtown"
$test.Item.Value()
$syncHash.dataTable.'Mod Webpage'
$test.'Mod Webpage'
Update-Window -Control $syncHash.ModsListDataGrid -Property 'background' -Value "#000000"
$syncHash.dataTable.Item.Value
$test = $syncHash.ModsListDataGrid.Items | Where-Object -Property 'Mod Name' -EQ "Downtown"
$syncHash.StatusBarText.Dispatcher.Invoke([action]{$syncHash.StatusBarText.Text = "something"}, "Normal")
$syncHash.ModsListDataGrid.Dispatcher.Invoke([action]{$syncHash.ModsListDataGrid.RowBackground = "#FFFFFF"}, "Normal")
$syncHash.ModsListDataGrid
$syncHash.dataTable.DefaultView.RowFilter = "ModName LIKE 'Downtown'"
$syncHash.dataTable.DefaultView.RowFilter = ""
($syncHash.dataTable.Rows | Where-Object {$_.ModName -match ".500"}).ModWebpage = "Test"
$syncHash.ModsListDataGrid.ItemsSource = $syncHash.dataTable.DefaultView
Update-Window -Control ModsListDataGrid -Property "ItemsSource" -Value $syncHash.dataTable.DefaultView
#>
