
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
            $modInfo         = Get-Content -Path "$($mod.Fullname)\info.txt"
            $modName         = if (($modInfo -match 'name = ' -split 'name = ')[1].Length -gt 2) {($modInfo -match 'name = ' -split 'name = ')[1] -replace "_",' '} else {"modName not found"}
            $modAuthor       = if (($modInfo -match 'author = ' -split 'author = ')[1].Length -gt 2) {($modInfo -match 'author = ' -split 'author = ')[1]} else {"modAuthor not found"}
            $modDescription  = if (($modInfo -match 'description = ' -split 'description = ')[1].Length -gt 2) {($modInfo -match 'description = ' -split 'description = ')[1]} else {"modDescription not found"}
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
                'ModName' = $modName
                'ModAuthor' = $modAuthor
                'ModDescription' = $modDescription
                'ModPath' = $mod.Fullname
                'ModWebPage' = if ($modWebLink.Length -gt 25) {$modWebLink} else {"NA"}
                'ModDownload' = if ($modPackageDownloadLink.Length -gt 25) {$modPackageDownloadLink} else {"NA"}
                'modSearchName' = $modSearchName
            }
        
            $modInfo = $null
            $modName = $null
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
    Title="Teardown Mod Manager v0.1.0 | by Timothy Gruber" Height="500" Width="958" ScrollViewer.VerticalScrollBarVisibility="Disabled">
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
                <TabItem Header="Installed Mods" HorizontalAlignment="Left" Height="20" VerticalAlignment="Top" TextOptions.TextFormattingMode="Display">
                    <DockPanel Margin="0,5,0,0">
                        <Grid DockPanel.Dock="Bottom" Margin="5,1"/>
                        <DockPanel DockPanel.Dock="Right" Margin="0">
                            <DockPanel DockPanel.Dock="Top" Margin="0">
                                <Button DockPanel.Dock="Left" Name="UpdateSelectedMod" Content="Update Selected Mod" VerticalAlignment="Center" Height="30" FontSize="14" Padding="10,1" Margin="5,0" HorizontalAlignment="Right" FontWeight="Bold"/>
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
                <TabItem Header="Help" HorizontalAlignment="Left" Height="20" VerticalAlignment="Top" TextOptions.TextFormattingMode="Display">
                    <DockPanel Margin="0,5,0,0">
                        <GroupBox Header="about" DockPanel.Dock="Bottom" VerticalAlignment="Bottom" FontWeight="Bold">
                            <ScrollViewer>
                                <TextBlock TextWrapping="Wrap" FontWeight="Normal"><Run FontWeight="Bold" Text="Created by: "/><Run Text="&#x9;Timothy Gruber&#xA;"/><Run FontWeight="Bold" Text="Website:&#x9;"/><Hyperlink NavigateUri="https://timothygruber.com/"><Run Text="TimothyGruber.com&#xA;"/></Hyperlink><Run FontWeight="Bold" Text="Gitlab:&#x9;&#x9;"/><Hyperlink NavigateUri="https://gitlab.com/tjgruber/PoShGUI365"><Run Text="https://gitlab.com/tjgruber/PoShGUI365&#xA;"/></Hyperlink><Run FontWeight="Bold" Text="Version:"/><Run Text="&#x9;&#x9;2021.01.28.0.1.0"/></TextBlock>
                            </ScrollViewer>
                        </GroupBox>
                        <GroupBox Header="Instructions..." FontWeight="Bold">
                            <TabControl TabStripPlacement="Left">
                                <TabItem Header="General" Height="20" TextOptions.TextFormattingMode="Display" VerticalAlignment="Top" HorizontalContentAlignment="Stretch">
                                    <GroupBox Header="General">
                                        <ScrollViewer>
                                            <TextBlock  TextWrapping="Wrap" FontWeight="Normal"><Run FontWeight="Normal" Text="This script is used to manage installed Teardown mods."/><LineBreak/><Run FontWeight="Normal"/><LineBreak/><Run FontWeight="Normal" Text="All mods are checked against teardownmods.com"/><LineBreak/><Run FontWeight="Normal"/><LineBreak/><Run FontWeight="Normal" Text="The sign-in button is not yet functional."/></TextBlock>
                                        </ScrollViewer>
                                    </GroupBox>
                                </TabItem>
                                <TabItem Header="Installed Mods Tab" Height="20" VerticalAlignment="Top" TextOptions.TextFormattingMode="Display">
                                    <GroupBox Header="Services">
                                        <ScrollViewer>
                                            <TextBlock ><Run FontWeight="Normal" Text="    1.  ...in progress."/></TextBlock>
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
            $row.ModAuthor          = $modItem.ModAuthor
            $row.ModDescription     = $modItem.ModDescription
            $row.ModPath            = $modItem.ModPath
            $row.ModWebpage         = $modItem.ModWebPage
            $row.ModDownloadLink    = $modItem.ModDownload

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

        Update-Window -Control StatusBarText -Property Text -Value "Updating mod: [$(($syncHash.ModsListDataGrid.SelectedCells | Select-Object -First 1).Item.ModName)]..."

        $UpdateSelectedModRunspace = [runspacefactory]::CreateRunspace()
        $UpdateSelectedModRunspace.Name = "SignInWindow"
        $UpdateSelectedModRunspace.ApartmentState = "STA"
        $UpdateSelectedModRunspace.ThreadOptions = "ReuseThread"
        $UpdateSelectedModRunspace.Open()
        $UpdateSelectedModRunspace.SessionStateProxy.SetVariable("syncHash", $syncHash)

        $UpdateSelectedModRunspaceScript = [PowerShell]::Create().AddScript({

            #############################################
            #############################################
            #region FUNCTIONS
            #############################################
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
                        $modSearchName = $mod.modSearchName
                        $modName = $mod.ModName
                        $modAuthor = $mod.ModAuthor
                        $modDescription = $mod.ModDescription
                        $modSearchURI = "https://teardownmods.com/index.php?/search/&q=" + ($modSearchName -replace " ",'%20' -replace "_",'%20' -replace "'s",'') + "&search_and_or=or&sortby=relevancy"
                        #Write-Host "`tSearching teardownmods.com for mod at: [$modSearchURI]"
                        $modSearchResults = Invoke-WebRequest $modSearchURI -UseBasicParsing -ErrorAction SilentlyContinue
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
                    
                        if ($modWebLink) {
                            #Write-Host "`tAccessing mod web page at teardownmods.com at: [$modWebLink]"
                            $modWebPage = Invoke-WebRequest -Uri $modWebLink -SessionVariable mwp -UseBasicParsing -ErrorAction SilentlyContinue
                            $modDownloadLink = ($modWebPage.Links | Where-Object {$_ -match '&amp;do=download&amp;csrfKey='} | Select-Object -First 1).href -replace '&amp;','&'
                            #Write-Host "`tAccessing mod download page at teardownmods.com at: [$modDownloadLink]"
                            $modPackageDownloadPage = Invoke-WebRequest -Uri $modDownloadLink -Method Get -WebSession $mwp -UseBasicParsing -ErrorAction SilentlyContinue
                            $modPackageDownloadLink = ($modPackageDownloadPage.Links | Where-Object {$_.'data-action' -eq 'download'} | Select-Object -Last 1).href -replace '&amp;','&'
                            #Write-Host "`tAssuming mod package download link at teardownmods.com is: [$modPackageDownloadLink]"
                        } else {
                            #Write-Warning "Mod [$modName] not found in teardownmods.com search results!"
                        }
                    
                        [PSCustomObject]@{
                            'ModName' = $modName
                            'ModAuthor' = $modAuthor
                            'ModDescription' = $modDescription
                            'ModPath' = $mod.Fullname
                            'ModWebPage' = if ($modWebLink.Length -gt 25) {$modWebLink} else {"Not Found"}
                            'ModDownload' = if ($modPackageDownloadLink.Length -gt 25) {$modPackageDownloadLink} else {"Not Found"}
                        }
                    
                        $modInfo = $null
                        $modName = $null
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
            #############################################
            #endRegion FUNCTIONS
            #############################################
            #############################################

            #$allModsData = Get-ModData -allMods ($syncHash.allModsDeetz | Select-Object -First 3)
            $allModsData = Get-ModData -allMods ($syncHash.allModsDeetz | Where-Object -Property ModName -EQ (($syncHash.ModsListDataGrid.SelectedCells | Select-Object -First 1).Item.ModName))

            foreach ($modItem in $allModsData) {

                ($syncHash.dataTable.Rows | Where-Object {$_.ModName -eq $modItem.modName}).ModWebPage = $modItem.ModWebPage
                ($syncHash.dataTable.Rows | Where-Object {$_.ModName -eq $modItem.modName}).ModDownload = $modItem.ModWebPage

            }

            Update-Window -Control StatusBarText -Property Text -Value "Mod updated: [$(($syncHash.ModsListDataGrid.SelectedCells | Select-Object -First 1).Item.ModName)] | Ready..."

        })

        $UpdateSelectedModRunspaceScript.Runspace = $UpdateSelectedModRunspace
        $data = $UpdateSelectedModRunspaceScript.BeginInvoke()

    })

    #############################################
    #############################################
    #endRegion UPDATE SELECTED MOD BUTTON
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
