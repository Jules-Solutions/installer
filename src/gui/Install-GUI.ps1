<#
.SYNOPSIS
    Jules.Solutions Universal Installer GUI
.DESCRIPTION
    WPF-based installer supporting Install, Update, and Uninstall modes.
    Manifest-driven: apps define their options and steps.
.PARAMETER Manifest
    The app manifest object (from Get-AppManifest)
.PARAMETER Repo
    The repository in owner/repo format
.PARAMETER Mode
    Operation mode: Menu (show selection), Install, Update, Uninstall
.PARAMETER AppPath
    Path to installed app (for Update/Uninstall modes)
.NOTES
    Requires: Windows 10/11, PowerShell 5.1+, .NET Framework 4.5+
#>

param(
    [Parameter(Mandatory)]
    $Manifest,
    
    [Parameter(Mandatory)]
    [string]$Repo,
    
    [ValidateSet("Menu", "Install", "Update", "Uninstall")]
    [string]$Mode = "Menu",
    
    [string]$AppPath = "$env:LOCALAPPDATA\Jules.Solutions\apps\devcli"
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ============================================================================
# THEME COLORS (inline for portability)
# ============================================================================
$colors = @{
    Primary    = "#e94560"
    PrimaryHover = "#ff6b6b"
    Secondary  = "#0f3460"
    Background = "#1a1a2e"
    Surface    = "#252542"
    SurfaceHover = "#2a2a4a"
    Text       = "#eaeaea"
    SubText    = "#a0a0a0"
    Muted      = "#666666"
    Border     = "#555555"
    Success    = "#4ade80"
    Error      = "#ef4444"
    Warning    = "#f59e0b"
    Footer     = "#16162a"
}

# ============================================================================
# XAML GENERATION
# ============================================================================
function New-InstallerXaml {
    param($Manifest, $Colors)
    
    $appName = $Manifest.name
    $appDesc = $Manifest.description
    
    # Build options UI
    $optionsXaml = Build-OptionsXaml -Options $Manifest.options -Colors $Colors
    
    # Build variables UI (input fields)
    $variablesXaml = Build-VariablesXaml -Variables $Manifest.variables -Colors $Colors
    
    # Build completion actions
    $completionXaml = Build-CompletionXaml -Completion $Manifest.completion -Colors $Colors
    
    # Build uninstall options (manifest-driven)
    $uninstallXaml = Build-UninstallXaml -Uninstall $Manifest.uninstall -Colors $Colors

    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Jules.Solutions - $appName"
        Height="620" Width="680"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        Background="$($Colors.Background)">
    
    <Window.Resources>
        <!-- Button Styles -->
        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Background" Value="$($Colors.Primary)"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="25,12"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="$($Colors.PrimaryHover)"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Background" Value="#555"/>
                                <Setter Property="Foreground" Value="#888"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        
        <Style x:Key="SecondaryButton" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="$($Colors.SubText)"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Padding" Value="25,12"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="$($Colors.Border)"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="BorderBrush" Value="$($Colors.Primary)"/>
                                <Setter Property="Foreground" Value="$($Colors.Primary)"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        
        <!-- Input Style -->
        <Style x:Key="InputBox" TargetType="TextBox">
            <Setter Property="Background" Value="$($Colors.Surface)"/>
            <Setter Property="Foreground" Value="$($Colors.Text)"/>
            <Setter Property="FontSize" Value="16"/>
            <Setter Property="Padding" Value="15,12"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="$($Colors.Border)"/>
            <Setter Property="CaretBrush" Value="$($Colors.Primary)"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6">
                            <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsFocused" Value="True">
                                <Setter Property="BorderBrush" Value="$($Colors.Primary)"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        
        <!-- Radio Option Style -->
        <Style x:Key="InstallOption" TargetType="RadioButton">
            <Setter Property="Foreground" Value="$($Colors.Text)"/>
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="Margin" Value="0,8"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RadioButton">
                        <Border x:Name="border" Background="$($Colors.Surface)" CornerRadius="8" Padding="20,15" Margin="0,5">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="30"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Ellipse x:Name="outer" Width="20" Height="20" Stroke="$($Colors.Border)" StrokeThickness="2" Fill="Transparent"/>
                                <Ellipse x:Name="inner" Width="10" Height="10" Fill="$($Colors.Primary)" Visibility="Hidden"/>
                                <ContentPresenter Grid.Column="1" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="inner" Property="Visibility" Value="Visible"/>
                                <Setter TargetName="outer" Property="Stroke" Value="$($Colors.Primary)"/>
                                <Setter TargetName="border" Property="Background" Value="$($Colors.SurfaceHover)"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="$($Colors.Primary)"/>
                                <Setter TargetName="border" Property="BorderThickness" Value="1"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="$($Colors.SurfaceHover)"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="70"/>
        </Grid.RowDefinitions>
        
        <!-- Main Content -->
        <Grid Grid.Row="0" Margin="40,30,40,10">
            
            <!-- Page -1: Mode Selection -->
            <StackPanel x:Name="PageModeSelect" Visibility="Collapsed">
                <TextBlock Text="JS" FontSize="42" Foreground="$($Colors.Primary)" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,10,0,15"/>
                <TextBlock Text="Jules.Solutions" Foreground="$($Colors.Primary)" FontSize="26" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,0,0,5"/>
                <TextBlock Text="$appName" Foreground="$($Colors.Text)" FontSize="16" HorizontalAlignment="Center" Margin="0,0,0,25"/>
                
                <Border x:Name="CardInstall" Background="$($Colors.Surface)" CornerRadius="12" Padding="25,20" Margin="0,8" Cursor="Hand">
                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="50"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                        <TextBlock Text="⬇" FontSize="28" Foreground="$($Colors.Success)" VerticalAlignment="Center" FontFamily="Segoe UI Symbol"/>
                        <StackPanel Grid.Column="1">
                            <TextBlock Text="Install" Foreground="$($Colors.Text)" FontSize="18" FontWeight="SemiBold"/>
                            <TextBlock Text="Fresh installation of $appName" Foreground="$($Colors.SubText)" FontSize="13"/>
                        </StackPanel>
                    </Grid>
                </Border>
                
                <Border x:Name="CardUpdate" Background="$($Colors.Surface)" CornerRadius="12" Padding="25,20" Margin="0,8" Cursor="Hand">
                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="50"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                        <TextBlock Text="⟳" FontSize="28" Foreground="$($Colors.Warning)" VerticalAlignment="Center" FontFamily="Segoe UI Symbol"/>
                        <StackPanel Grid.Column="1">
                            <TextBlock Text="Update" Foreground="$($Colors.Text)" FontSize="18" FontWeight="SemiBold"/>
                            <TextBlock Text="Get latest features and fixes" Foreground="$($Colors.SubText)" FontSize="13"/>
                        </StackPanel>
                    </Grid>
                </Border>
                
                <Border x:Name="CardUninstall" Background="$($Colors.Surface)" CornerRadius="12" Padding="25,20" Margin="0,8" Cursor="Hand">
                    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="50"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                        <TextBlock Text="✕" FontSize="28" Foreground="$($Colors.Error)" VerticalAlignment="Center" FontFamily="Segoe UI Symbol"/>
                        <StackPanel Grid.Column="1">
                            <TextBlock Text="Uninstall" Foreground="$($Colors.Text)" FontSize="18" FontWeight="SemiBold"/>
                            <TextBlock Text="Remove $appName (choose what to keep)" Foreground="$($Colors.SubText)" FontSize="13"/>
                        </StackPanel>
                    </Grid>
                </Border>
            </StackPanel>
            
            <!-- Page 0: Welcome -->
            <StackPanel x:Name="PageWelcome" Visibility="Visible">
                <TextBlock Text="JS" FontSize="48" Foreground="$($Colors.Primary)" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,20,0,20"/>
                <TextBlock Text="Welcome to Jules.Solutions" Foreground="$($Colors.Primary)" FontSize="28" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,0,0,15"/>
                <TextBlock Text="$appName - $appDesc" Foreground="$($Colors.Text)" FontSize="16" HorizontalAlignment="Center" Margin="0,0,0,30"/>
                <TextBlock TextWrapping="Wrap" Foreground="$($Colors.SubText)" FontSize="14" HorizontalAlignment="Center" TextAlignment="Center" MaxWidth="500">
                    This wizard will install $appName and configure your environment.
                </TextBlock>
                <TextBlock Text="Click Next to continue." Foreground="$($Colors.Text)" FontSize="14" HorizontalAlignment="Center" Margin="0,40,0,0"/>
            </StackPanel>
            
            <!-- Page 1: Options -->
            <ScrollViewer x:Name="PageOptions" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel>
                    <TextBlock Text="Installation Options" Foreground="$($Colors.Primary)" FontSize="24" FontWeight="Bold" Margin="0,0,0,10"/>
                    <TextBlock Text="Configure your installation." Foreground="$($Colors.SubText)" FontSize="14" Margin="0,0,0,25"/>
                    $optionsXaml
                </StackPanel>
            </ScrollViewer>
            
            <!-- Page 2: Variables (user input) -->
            <StackPanel x:Name="PageVariables" Visibility="Collapsed">
                <TextBlock Text="Personalize" Foreground="$($Colors.Primary)" FontSize="24" FontWeight="Bold" Margin="0,0,0,10"/>
                <TextBlock Text="Enter your information." Foreground="$($Colors.SubText)" FontSize="14" Margin="0,0,0,30"/>
                $variablesXaml
            </StackPanel>
            
            <!-- Page 3: Installing -->
            <StackPanel x:Name="PageInstalling" Visibility="Collapsed">
                <TextBlock Text="Installing..." Foreground="$($Colors.Primary)" FontSize="24" FontWeight="Bold" Margin="0,0,0,10"/>
                <TextBlock x:Name="TxtStatus" Text="Preparing..." Foreground="$($Colors.SubText)" FontSize="14" Margin="0,0,0,30"/>
                <ProgressBar x:Name="ProgressBar" Height="8" Margin="0,0,0,20" Background="$($Colors.Surface)" Foreground="$($Colors.Primary)" BorderThickness="0" Maximum="100" Value="0"/>
                <Border Background="$($Colors.Surface)" CornerRadius="8" Padding="15" MaxHeight="200">
                    <ScrollViewer x:Name="LogScroller" VerticalScrollBarVisibility="Auto">
                        <TextBlock x:Name="TxtLog" Foreground="$($Colors.SubText)" FontSize="12" FontFamily="Consolas" TextWrapping="Wrap"/>
                    </ScrollViewer>
                </Border>
            </StackPanel>
            
            <!-- Page 4: Complete -->
            <StackPanel x:Name="PageComplete" Visibility="Collapsed">
                <TextBlock Text="✓" FontSize="48" Foreground="$($Colors.Success)" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,20,0,20"/>
                <TextBlock Text="Installation Complete!" Foreground="$($Colors.Success)" FontSize="28" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,0,0,15"/>
                <TextBlock x:Name="TxtCompleteMessage" Text="" Foreground="$($Colors.Text)" FontSize="16" HorizontalAlignment="Center" Margin="0,0,0,30"/>
                $completionXaml
            </StackPanel>
            
            <!-- Page 5: Error -->
            <StackPanel x:Name="PageError" Visibility="Collapsed">
                <TextBlock Text="✗" FontSize="48" Foreground="$($Colors.Error)" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,20,0,20"/>
                <TextBlock Text="Installation Failed" Foreground="$($Colors.Error)" FontSize="28" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,0,0,15"/>
                <TextBlock x:Name="TxtErrorMessage" Text="" Foreground="$($Colors.SubText)" FontSize="14" TextWrapping="Wrap" HorizontalAlignment="Center" TextAlignment="Center" MaxWidth="500" Margin="0,0,0,30"/>
                <Border Background="$($Colors.Surface)" CornerRadius="8" Padding="15" MaxHeight="150">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <TextBox x:Name="TxtErrorLog" Foreground="#aaa" FontSize="11" FontFamily="Consolas" TextWrapping="Wrap" IsReadOnly="True" Background="Transparent" BorderThickness="0"/>
                    </ScrollViewer>
                </Border>
            </StackPanel>
            
            <!-- Page 6: Uninstall Options (manifest-driven) -->
            <ScrollViewer x:Name="PageUninstall" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
                <StackPanel>
                    <TextBlock Text="Uninstall Options" Foreground="$($Colors.Primary)" FontSize="24" FontWeight="Bold" Margin="0,0,0,5"/>
                    <TextBlock Text="Select what to remove:" Foreground="$($Colors.SubText)" FontSize="14" Margin="0,0,0,20"/>
                    
                    <Border Background="$($Colors.Surface)" CornerRadius="8" Padding="20" Margin="0,0,0,15">
                        <StackPanel x:Name="UninstallOptionsContainer">
                            $uninstallXaml
                        </StackPanel>
                    </Border>
                    
                    <Border Background="#3b1f1f" CornerRadius="6" Padding="15">
                        <CheckBox x:Name="ChkUninstallAll" Foreground="$($Colors.Error)" FontSize="14" FontWeight="Bold">
                            <TextBlock Text="  SELECT ALL - Complete removal"/>
                        </CheckBox>
                    </Border>
                </StackPanel>
            </ScrollViewer>
        </Grid>
        
        <!-- Footer Navigation -->
        <Border Grid.Row="1" Background="$($Colors.Footer)" Padding="40,15">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <Button x:Name="BtnCancel" Content="Cancel" Style="{StaticResource SecondaryButton}" Grid.Column="0" HorizontalAlignment="Left"/>
                <Button x:Name="BtnBack" Content="Back" Style="{StaticResource SecondaryButton}" Grid.Column="1" Margin="0,0,10,0" Visibility="Collapsed"/>
                <Button x:Name="BtnNext" Content="Next" Style="{StaticResource PrimaryButton}" Grid.Column="2"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@
}

function Build-OptionsXaml {
    param($Options, $Colors)
    
    if (-not $Options -or $Options.Count -eq 0) {
        return ""
    }
    
    $xaml = ""
    
    foreach ($opt in $Options) {
        switch ($opt.type) {
            "radio" {
                $xaml += "<StackPanel x:Name=`"OptGroup_$($opt.id)`" Margin=`"0,0,0,15`">`n"
                $isFirst = $true
                foreach ($choice in $opt.choices) {
                    $checked = if ($choice.value -eq $opt.default) { "True" } else { "False" }
                    $xaml += @"
                    <RadioButton x:Name="Opt_$($opt.id)_$($choice.value)" Style="{StaticResource InstallOption}" IsChecked="$checked" GroupName="$($opt.id)">
                        <StackPanel>
                            <TextBlock Text="$($choice.label)" FontWeight="SemiBold"/>
                            <TextBlock Text="$($choice.description)" Foreground="$($Colors.SubText)" FontSize="12" Margin="0,3,0,0"/>
                        </StackPanel>
                    </RadioButton>
"@
                }
                $xaml += "</StackPanel>`n"
            }
            "checkbox" {
                $checked = if ($opt.default) { "True" } else { "False" }
                $xaml += @"
                <CheckBox x:Name="Opt_$($opt.id)" Content="  $($opt.label)" Foreground="$($Colors.Text)" FontSize="14" IsChecked="$checked" Margin="0,8"/>
"@
            }
        }
    }
    
    return $xaml
}

function Build-VariablesXaml {
    param($Variables, $Colors)
    
    if (-not $Variables) {
        return ""
    }
    
    $xaml = ""
    
    $Variables.PSObject.Properties | ForEach-Object {
        $varName = $_.Name
        $varDef = $_.Value
        
        $xaml += @"
        <TextBlock Text="$($varDef.prompt):" Foreground="$($Colors.Text)" FontSize="14" Margin="0,0,0,8"/>
        <TextBox x:Name="Var_$varName" Style="{StaticResource InputBox}" MaxLength="50"/>
        <TextBlock Text="$($varDef.description)" Foreground="$($Colors.Muted)" FontSize="12" Margin="0,5,0,20"/>
"@
    }
    
    return $xaml
}

function Build-CompletionXaml {
    param($Completion, $Colors)
    
    if (-not $Completion -or -not $Completion.actions) {
        return ""
    }
    
    $xaml = "<StackPanel HorizontalAlignment=`"Center`">`n"
    
    foreach ($action in $Completion.actions) {
        $checked = if ($action.default) { "True" } else { "False" }
        $xaml += @"
        <CheckBox x:Name="Action_$($action.label -replace '\s','')" Content="  $($action.label)" Foreground="$($Colors.SubText)" FontSize="14" IsChecked="$checked" Margin="0,8"/>
"@
    }
    
    $xaml += "</StackPanel>"
    return $xaml
}

function Build-UninstallXaml {
    param($Uninstall, $Colors)
    
    if (-not $Uninstall -or -not $Uninstall.options) {
        return ""
    }
    
    $xaml = ""
    
    foreach ($opt in $Uninstall.options) {
        $checked = if ($opt.default) { "True" } else { "False" }
        $textColor = if ($opt.danger) { $Colors.Error } elseif ($opt.warning) { $Colors.Warning } else { $Colors.Text }
        $descColor = if ($opt.danger) { $Colors.Error } elseif ($opt.warning) { $Colors.Warning } else { $Colors.Muted }
        $warningPrefix = if ($opt.danger -or $opt.warning) { "⚠️ " } else { "" }
        
        $xaml += @"
                            <CheckBox x:Name="ChkUninstall_$($opt.id)" IsChecked="$checked" Foreground="$textColor" FontSize="14" Margin="0,8">
                                <StackPanel>
                                    <TextBlock Text="$($opt.label)" FontWeight="SemiBold" Foreground="$textColor"/>
                                    <TextBlock Text="$warningPrefix$($opt.description)" Foreground="$descColor" FontSize="12"/>
                                </StackPanel>
                            </CheckBox>
"@
    }
    
    return $xaml
}

# ============================================================================
# CREATE WINDOW
# ============================================================================
$xaml = New-InstallerXaml -Manifest $Manifest -Colors $colors

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get elements
$pageModeSelect = $window.FindName("PageModeSelect")
$pageWelcome = $window.FindName("PageWelcome")
$pageOptions = $window.FindName("PageOptions")
$pageVariables = $window.FindName("PageVariables")
$pageInstalling = $window.FindName("PageInstalling")
$pageComplete = $window.FindName("PageComplete")
$pageError = $window.FindName("PageError")
$pageUninstall = $window.FindName("PageUninstall")

# Mode cards
$cardInstall = $window.FindName("CardInstall")
$cardUpdate = $window.FindName("CardUpdate")
$cardUninstall = $window.FindName("CardUninstall")

# Uninstall checkboxes - found dynamically from manifest
$chkUninstallAll = $window.FindName("ChkUninstallAll")
$uninstallOptionsContainer = $window.FindName("UninstallOptionsContainer")

$txtStatus = $window.FindName("TxtStatus")
$txtLog = $window.FindName("TxtLog")
$logScroller = $window.FindName("LogScroller")
$progressBar = $window.FindName("ProgressBar")
$txtCompleteMessage = $window.FindName("TxtCompleteMessage")
$txtErrorMessage = $window.FindName("TxtErrorMessage")
$txtErrorLog = $window.FindName("TxtErrorLog")

$btnCancel = $window.FindName("BtnCancel")
$btnBack = $window.FindName("BtnBack")
$btnNext = $window.FindName("BtnNext")

# State
$script:currentPage = -1  # Start at mode select if Menu mode
$script:currentMode = $Mode
$script:installLog = ""
$script:values = @{}  # Collected variable/option values
$script:isInstalling = $false

# ============================================================================
# NAVIGATION
# ============================================================================
function Hide-AllPages {
    $pageModeSelect.Visibility = "Collapsed"
    $pageWelcome.Visibility = "Collapsed"
    $pageOptions.Visibility = "Collapsed"
    $pageVariables.Visibility = "Collapsed"
    $pageInstalling.Visibility = "Collapsed"
    $pageComplete.Visibility = "Collapsed"
    $pageError.Visibility = "Collapsed"
    $pageUninstall.Visibility = "Collapsed"
}

function Show-Page {
    param([int]$page)
    
    Hide-AllPages
    
    $hasOptions = $Manifest.options -and $Manifest.options.Count -gt 0
    $hasVariables = $Manifest.variables -and $Manifest.variables.PSObject.Properties.Count -gt 0
    
    switch ($page) {
        -1 {  # Mode Selection
            $pageModeSelect.Visibility = "Visible"
            $btnBack.Visibility = "Collapsed"
            $btnNext.Visibility = "Collapsed"
            $btnCancel.Content = "Exit"
        }
        0 {  # Welcome
            $pageWelcome.Visibility = "Visible"
            $btnBack.Visibility = if ($script:currentMode -eq "Menu") { "Visible" } else { "Collapsed" }
            $btnNext.Visibility = "Visible"
            $btnNext.Content = "Next"
            $btnCancel.Content = "Cancel"
            $btnCancel.Visibility = "Visible"
        }
        1 {  # Options (skip if none)
            if ($hasOptions) {
                $pageOptions.Visibility = "Visible"
                $btnBack.Visibility = "Visible"
                $btnNext.Content = if ($hasVariables) { "Next" } else { "Install" }
            } else {
                Show-Page 2
                return
            }
        }
        2 {  # Variables (skip if none)
            if ($hasVariables) {
                $pageVariables.Visibility = "Visible"
                $btnBack.Visibility = "Visible"
                $btnNext.Content = "Install"
                Initialize-VariableDefaults
            } else {
                Show-Page 3
                return
            }
        }
        3 {  # Installing
            $pageInstalling.Visibility = "Visible"
            $btnBack.Visibility = "Collapsed"
            $btnNext.Visibility = "Collapsed"
            $btnCancel.IsEnabled = $true
        }
        4 {  # Complete
            $pageComplete.Visibility = "Visible"
            $btnBack.Visibility = "Collapsed"
            $btnNext.Content = "Finish"
            $btnNext.Visibility = "Visible"
            $btnCancel.Visibility = "Collapsed"
            if ($Manifest.completion.message) {
                $txtCompleteMessage.Text = $Manifest.completion.message
            }
        }
        5 {  # Error
            $pageError.Visibility = "Visible"
            $btnBack.Visibility = "Collapsed"
            $btnNext.Content = "Close"
            $btnNext.Visibility = "Visible"
            $btnCancel.Visibility = "Collapsed"
        }
        6 {  # Uninstall Options
            $pageUninstall.Visibility = "Visible"
            $btnBack.Visibility = "Visible"
            $btnNext.Content = "Uninstall"
            $btnNext.Visibility = "Visible"
            $btnCancel.Visibility = "Visible"
        }
    }
    
    $script:currentPage = $page
}

function Initialize-VariableDefaults {
    if (-not $Manifest.variables) { return }
    
    $Manifest.variables.PSObject.Properties | ForEach-Object {
        $varName = $_.Name
        $varDef = $_.Value
        $textBox = $window.FindName("Var_$varName")
        
        if ($textBox -and [string]::IsNullOrEmpty($textBox.Text)) {
            $default = $varDef.default
            if ($default -match '^\$env:(\w+)$') {
                $default = [Environment]::GetEnvironmentVariable($matches[1])
            }
            $textBox.Text = $default
        }
    }
}

function Collect-Values {
    $script:values = @{}
    
    # Collect options
    if ($Manifest.options) {
        foreach ($opt in $Manifest.options) {
            switch ($opt.type) {
                "radio" {
                    foreach ($choice in $opt.choices) {
                        $rb = $window.FindName("Opt_$($opt.id)_$($choice.value)")
                        if ($rb -and $rb.IsChecked) {
                            $script:values[$opt.id] = $choice.value
                            break
                        }
                    }
                }
                "checkbox" {
                    $cb = $window.FindName("Opt_$($opt.id)")
                    if ($cb) {
                        $script:values[$opt.id] = $cb.IsChecked
                    }
                }
            }
        }
    }
    
    # Collect variables
    if ($Manifest.variables) {
        $Manifest.variables.PSObject.Properties | ForEach-Object {
            $varName = $_.Name
            $textBox = $window.FindName("Var_$varName")
            if ($textBox) {
                $script:values[$varName] = $textBox.Text.Trim()
            }
        }
    }
    
    # Add built-ins
    $script:values['repo'] = $Repo
    $script:values['version'] = $Manifest.version
    $script:values['installDir'] = "$env:LOCALAPPDATA\Jules.Solutions\apps\$($Manifest.name.ToLower())"
}

function Validate-Variables {
    if (-not $Manifest.variables) { return $true }
    
    $valid = $true
    $Manifest.variables.PSObject.Properties | ForEach-Object {
        $varName = $_.Name
        $varDef = $_.Value
        $textBox = $window.FindName("Var_$varName")
        
        if ($textBox) {
            $value = $textBox.Text.Trim()
            
            if ([string]::IsNullOrEmpty($value)) {
                [System.Windows.MessageBox]::Show("Please enter $($varDef.prompt).", "Validation", "OK", "Warning")
                $valid = $false
                return
            }
            
            if ($varDef.validation -and $value -notmatch $varDef.validation) {
                [System.Windows.MessageBox]::Show("Invalid value for $($varDef.prompt).", "Validation", "OK", "Warning")
                $valid = $false
                return
            }
        }
    }
    
    return $valid
}

# ============================================================================
# LOGGING
# ============================================================================
function Write-Log {
    param([string]$msg)
    $script:installLog += "$msg`n"
    $window.Dispatcher.Invoke([Action]{
        $txtLog.Text = $script:installLog
        $logScroller.ScrollToEnd()
    })
}

function Update-Progress {
    param([int]$pct, [string]$status)
    $window.Dispatcher.Invoke([Action]{
        $progressBar.Value = $pct
        $txtStatus.Text = $status
    })
}

# ============================================================================
# INSTALLATION (runs in background)
# ============================================================================
function Start-Installation {
    Collect-Values
    
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()
    
    # Pass variables to runspace
    $runspace.SessionStateProxy.SetVariable("window", $window)
    $runspace.SessionStateProxy.SetVariable("Manifest", $Manifest)
    $runspace.SessionStateProxy.SetVariable("Repo", $Repo)
    $runspace.SessionStateProxy.SetVariable("values", $script:values)
    $runspace.SessionStateProxy.SetVariable("txtLog", $txtLog)
    $runspace.SessionStateProxy.SetVariable("logScroller", $logScroller)
    $runspace.SessionStateProxy.SetVariable("progressBar", $progressBar)
    $runspace.SessionStateProxy.SetVariable("txtStatus", $txtStatus)
    $runspace.SessionStateProxy.SetVariable("txtCompleteMessage", $txtCompleteMessage)
    $runspace.SessionStateProxy.SetVariable("txtErrorMessage", $txtErrorMessage)
    $runspace.SessionStateProxy.SetVariable("txtErrorLog", $txtErrorLog)
    $runspace.SessionStateProxy.SetVariable("pageInstalling", $pageInstalling)
    $runspace.SessionStateProxy.SetVariable("pageComplete", $pageComplete)
    $runspace.SessionStateProxy.SetVariable("pageError", $pageError)
    $runspace.SessionStateProxy.SetVariable("btnNext", $btnNext)
    $runspace.SessionStateProxy.SetVariable("btnCancel", $btnCancel)
    
    $powershell = [powershell]::Create()
    $powershell.Runspace = $runspace
    $script:isInstalling = $true
    
    [void]$powershell.AddScript({
        $installLog = ""
        
        function Write-Log {
            param([string]$msg)
            $script:installLog += "$msg`n"
            $window.Dispatcher.Invoke([Action]{
                $txtLog.Text = $script:installLog
                $logScroller.ScrollToEnd()
            })
        }
        
        function Update-Progress {
            param([int]$pct, [string]$status)
            $window.Dispatcher.Invoke([Action]{
                $progressBar.Value = $pct
                $txtStatus.Text = $status
            })
        }
        
        function Resolve-Template {
            param([string]$template)
            $result = $template
            foreach ($key in $values.Keys) {
                $result = $result -replace "\`$\{$key\}", $values[$key]
            }
            return $result
        }
        
        function Test-Condition {
            param([string]$condition)
            if ([string]::IsNullOrEmpty($condition) -or $condition -eq 'true') { return $true }
            if ($condition -eq 'false') { return $false }
            
            $expr = Resolve-Template $condition
            try { return [bool](Invoke-Expression $expr) }
            catch { return $true }
        }
        
        function Show-Complete {
            $window.Dispatcher.Invoke([Action]{
                $pageInstalling.Visibility = "Collapsed"
                $pageComplete.Visibility = "Visible"
                $btnNext.Content = "Finish"
                $btnNext.Visibility = "Visible"
                $window.Tag = 4
            })
        }
        
        function Show-Error {
            param([string]$msg)
            $window.Dispatcher.Invoke([Action]{
                $txtErrorMessage.Text = $msg
                $txtErrorLog.Text = $script:installLog
                $pageInstalling.Visibility = "Collapsed"
                $pageError.Visibility = "Visible"
                $btnNext.Content = "Close"
                $btnNext.Visibility = "Visible"
                $window.Tag = 5
            })
        }
        
        try {
            $steps = $Manifest.steps
            $totalSteps = ($steps | Where-Object { Test-Condition $_.condition }).Count
            $currentStep = 0
            $appsPath = "$env:LOCALAPPDATA\Jules.Solutions\apps"
            $appPath = Join-Path $appsPath $Manifest.name.ToLower()
            
            # Clone/update repo first
            Update-Progress 5 "Preparing repository..."
            Write-Log "[0/$totalSteps] Cloning $Repo..."
            
            if (-not (Test-Path $appsPath)) {
                New-Item -ItemType Directory -Path $appsPath -Force | Out-Null
            }
            
            if (Test-Path $appPath) {
                Write-Log "  Updating existing installation..."
                Push-Location $appPath
                git pull 2>&1 | ForEach-Object { Write-Log "  $_" }
                Pop-Location
            } else {
                Write-Log "  Cloning from GitHub..."
                $result = & gh repo clone $Repo $appPath 2>&1
                Write-Log "  $result"
                if (-not (Test-Path $appPath)) {
                    throw "Failed to clone repository"
                }
            }
            Write-Log "  [OK] Repository ready"
            
            # Run each step
            foreach ($step in $steps) {
                if (-not (Test-Condition $step.condition)) {
                    Write-Log "[$($currentStep+1)/$totalSteps] Skipping $($step.name) (condition not met)"
                    continue
                }
                
                $currentStep++
                $pct = [int](5 + (90 * $currentStep / $totalSteps))
                Update-Progress $pct $step.name
                Write-Log "[$currentStep/$totalSteps] $($step.name)..."
                
                $scriptPath = Join-Path $appPath $step.script
                if (-not (Test-Path $scriptPath)) {
                    throw "Step script not found: $($step.script)"
                }
                
                # Build arguments
                $scriptArgs = @()
                if ($step.args) {
                    foreach ($arg in $step.args) {
                        $scriptArgs += Resolve-Template $arg
                    }
                }
                
                # Run script
                $psExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
                if (-not (Test-Path $psExe)) { $psExe = "powershell" }
                
                $result = & $psExe -ExecutionPolicy Bypass -NoProfile -File $scriptPath @scriptArgs 2>&1
                $result | ForEach-Object { Write-Log "  $_" }
                
                if ($LASTEXITCODE -ne 0) {
                    throw "$($step.name) failed (exit code: $LASTEXITCODE)"
                }
                
                Write-Log "  [OK] Done"
                
                # Refresh PATH after each step
                $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + 
                           [Environment]::GetEnvironmentVariable('PATH', 'User')
            }
            
            Update-Progress 100 "Complete!"
            Write-Log ""
            Write-Log "========================================="
            Write-Log "  Installation completed successfully!"
            Write-Log "========================================="
            
            Start-Sleep -Milliseconds 500
            Show-Complete
            
        } catch {
            Write-Log ""
            Write-Log "ERROR: $_"
            Show-Error $_.Exception.Message
        }
    })
    
    $null = $powershell.BeginInvoke()
}

# ============================================================================
# UNINSTALL (script-driven, runs in background)
# ============================================================================
function Start-Uninstall {
    Show-Page 3  # Show installing page (repurposed for uninstall progress)
    $txtStatus.Text = "Preparing uninstall..."
    
    # Collect selected uninstall options from manifest
    $selectedOptions = @()
    if ($Manifest.uninstall -and $Manifest.uninstall.options) {
        foreach ($opt in $Manifest.uninstall.options) {
            $chk = $window.FindName("ChkUninstall_$($opt.id)")
            if ($chk -and $chk.IsChecked -eq $true) {
                $selectedOptions += $opt
            }
        }
    }
    
    if ($selectedOptions.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please select at least one option to uninstall.", "Nothing Selected", "OK", "Warning")
        Show-Page 6
        return
    }
    
    Write-Host "Selected uninstall options: $($selectedOptions.id -join ', ')"
    
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()
    
    # Pass variables to runspace
    $runspace.SessionStateProxy.SetVariable("window", $window)
    $runspace.SessionStateProxy.SetVariable("Manifest", $Manifest)
    $runspace.SessionStateProxy.SetVariable("Repo", $Repo)
    $runspace.SessionStateProxy.SetVariable("selectedOptions", $selectedOptions)
    $runspace.SessionStateProxy.SetVariable("txtLog", $txtLog)
    $runspace.SessionStateProxy.SetVariable("logScroller", $logScroller)
    $runspace.SessionStateProxy.SetVariable("progressBar", $progressBar)
    $runspace.SessionStateProxy.SetVariable("txtStatus", $txtStatus)
    $runspace.SessionStateProxy.SetVariable("txtCompleteMessage", $txtCompleteMessage)
    $runspace.SessionStateProxy.SetVariable("txtErrorMessage", $txtErrorMessage)
    $runspace.SessionStateProxy.SetVariable("txtErrorLog", $txtErrorLog)
    $runspace.SessionStateProxy.SetVariable("pageComplete", $pageComplete)
    $runspace.SessionStateProxy.SetVariable("pageError", $pageError)
    $runspace.SessionStateProxy.SetVariable("pageInstalling", $pageInstalling)
    $runspace.SessionStateProxy.SetVariable("btnNext", $btnNext)
    $runspace.SessionStateProxy.SetVariable("btnCancel", $btnCancel)
    
    $powershell = [powershell]::Create()
    $powershell.Runspace = $runspace
    $script:isInstalling = $true
    
    [void]$powershell.AddScript({
        $installLog = ""
        
        function Write-Log {
            param([string]$msg)
            $script:installLog += "$msg`n"
            $window.Dispatcher.Invoke([Action]{
                $txtLog.Text = $script:installLog
                $logScroller.ScrollToEnd()
            })
        }
        
        function Update-Progress {
            param([int]$pct, [string]$status)
            $window.Dispatcher.Invoke([Action]{
                $progressBar.Value = $pct
                $txtStatus.Text = $status
            })
        }
        
        function Show-Complete {
            $window.Dispatcher.Invoke([Action]{
                $pageComplete.Visibility = "Visible"
                $pageInstalling.Visibility = "Collapsed"
                $txtCompleteMessage.Text = "Uninstall completed successfully."
                $btnNext.Content = "Finish"
                $btnNext.Visibility = "Visible"
                $btnCancel.Visibility = "Collapsed"
                $window.Tag = 4
            })
        }
        
        function Show-Error {
            param([string]$msg)
            $window.Dispatcher.Invoke([Action]{
                $pageError.Visibility = "Visible"
                $pageInstalling.Visibility = "Collapsed"
                $txtErrorMessage.Text = $msg
                $txtErrorLog.Text = $script:installLog
                $btnNext.Content = "Close"
                $btnNext.Visibility = "Visible"
                $btnCancel.Visibility = "Collapsed"
            })
        }
        
        function Get-GitHubFile {
            param([string]$Repo, [string]$Path)
            $content = gh api "repos/$Repo/contents/$Path" --jq '.content' 2>&1
            if ($LASTEXITCODE -ne 0) { return $null }
            try {
                return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($content))
            } catch { return $null }
        }
        
        try {
            $appName = if ($Manifest.name) { $Manifest.name } else { "App" }
            
            Write-Log "========================================="
            Write-Log "  $appName Uninstall"
            Write-Log "========================================="
            Write-Log ""
            
            $totalSteps = $selectedOptions.Count
            $currentStep = 0
            
            foreach ($opt in $selectedOptions) {
                $currentStep++
                $pct = [int](($currentStep / $totalSteps) * 100)
                Update-Progress $pct "Running: $($opt.label)..."
                Write-Log "[$currentStep/$totalSteps] $($opt.label)..."
                
                # Download script from app repo
                $scriptContent = Get-GitHubFile -Repo $Repo -Path $opt.script
                
                if (-not $scriptContent) {
                    Write-Log "  [SKIP] Script not found: $($opt.script)"
                    continue
                }
                
                # Save to temp and execute
                $tempScript = Join-Path $env:TEMP "uninstall-$($opt.id).ps1"
                Set-Content -Path $tempScript -Value $scriptContent -Encoding UTF8
                
                # Run the script
                $psExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
                if (-not (Test-Path $psExe)) { $psExe = "powershell" }
                
                $result = & $psExe -ExecutionPolicy Bypass -NoProfile -File $tempScript 2>&1
                $result | ForEach-Object { Write-Log "  $_" }
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "  [WARNING] Script returned non-zero exit code: $LASTEXITCODE"
                } else {
                    Write-Log "  [OK] Done"
                }
                
                # Cleanup temp script
                Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
            }
            
            Update-Progress 100 "Uninstall complete!"
            Write-Log ""
            Write-Log "========================================="
            Write-Log "  Uninstall completed successfully!"
            Write-Log "========================================="
            
            Start-Sleep -Milliseconds 500
            Show-Complete
            
        } catch {
            Write-Log ""
            Write-Log "ERROR: $_"
            Show-Error $_.Exception.Message
        }
    })
    
    $null = $powershell.BeginInvoke()
}

# ============================================================================
# EVENT HANDLERS
# ============================================================================

# Mode selection cards
$cardInstall.Add_MouseLeftButtonUp({
    $script:currentMode = "Install"
    Show-Page 0
})

$cardUpdate.Add_MouseLeftButtonUp({
    $script:currentMode = "Update"
    Show-Page 0
})

$cardUninstall.Add_MouseLeftButtonUp({
    $script:currentMode = "Uninstall"
    Show-Page 6
})

# Select All checkbox for uninstall (works with dynamic checkboxes)
$chkUninstallAll.Add_Checked({
    if ($Manifest.uninstall -and $Manifest.uninstall.options) {
        foreach ($opt in $Manifest.uninstall.options) {
            $chk = $window.FindName("ChkUninstall_$($opt.id)")
            if ($chk) { $chk.IsChecked = $true }
        }
    }
})

$chkUninstallAll.Add_Unchecked({
    if ($Manifest.uninstall -and $Manifest.uninstall.options) {
        foreach ($opt in $Manifest.uninstall.options) {
            $chk = $window.FindName("ChkUninstall_$($opt.id)")
            if ($chk) { $chk.IsChecked = $false }
        }
    }
})

$btnCancel.Add_Click({
    if ($script:isInstalling) {
        # Could implement cancel logic here
    }
    $window.Close()
})

$btnBack.Add_Click({
    switch ($script:currentPage) {
        0 {  # From Welcome, go back to mode select if Menu mode
            if ($script:currentMode -eq "Menu") {
                Show-Page -1
            }
        }
        6 {  # From Uninstall, go back to mode select
            Show-Page -1
        }
        default {
            if ($script:currentPage -gt 0) {
                Show-Page ($script:currentPage - 1)
            }
        }
    }
})

$btnNext.Add_Click({
    if ($window.Tag -ne $null) {
        $script:currentPage = [int]$window.Tag
    }
    
    $hasOptions = $Manifest.options -and $Manifest.options.Count -gt 0
    $hasVariables = $Manifest.variables -and $Manifest.variables.PSObject.Properties.Count -gt 0
    
    switch ($script:currentPage) {
        0 { Show-Page 1 }
        1 { Show-Page 2 }
        2 {
            if (-not (Validate-Variables)) { return }
            Show-Page 3
            Start-Installation
        }
        4 {
            # Run completion actions
            if ($Manifest.completion -and $Manifest.completion.actions) {
                foreach ($action in $Manifest.completion.actions) {
                    $cbName = "Action_$($action.label -replace '\s','')"
                    $cb = $window.FindName($cbName)
                    if ($cb -and $cb.IsChecked) {
                        if ($action.command) {
                            Start-Process $action.command -ArgumentList $action.args
                        }
                    }
                }
            }
            $window.Close()
        }
        5 { $window.Close() }
        6 {
            # Execute uninstall
            Start-Uninstall
        }
    }
})

# ============================================================================
# RUN
# ============================================================================

# Determine starting page based on mode
switch ($Mode) {
    "Menu"      { Show-Page -1 }  # Mode selection
    "Install"   { Show-Page 0 }   # Welcome
    "Update"    { 
        $script:currentMode = "Update"
        Show-Page 0 
    }
    "Uninstall" { 
        $script:currentMode = "Uninstall"
        Show-Page 6  # Uninstall options
    }
    default     { Show-Page -1 }  # Default to mode selection
}

$window.ShowDialog() | Out-Null
