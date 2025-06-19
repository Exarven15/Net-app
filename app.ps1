Add-Type -AssemblyName PresentationFramework
Import-Module Posh-SSH

# Variables globales
$global:session = $null
$global:stream = $null

# Fonction pour charger les switches depuis un fichier CSV
function Load-Switches {
    $fichier = "liste_addr.csv"
    if (-Not (Test-Path $fichier)) {
        [System.Windows.MessageBox]::Show("Le fichier n'a pas ete trouve : $fichier", "Erreur", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return $null
    }
    try {
        $switches = Import-Csv -Path $fichier -Delimiter ';' -Encoding UTF8

        # Tri selon la valeur numérique au début du champ Name
        $switches = $switches | Sort-Object {[int]($_.Name -replace '^(\d+).*', '$1')}
    } catch {
        [System.Windows.MessageBox]::Show("Erreur lors de l'importation du fichier CSV.", "Erreur", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return $null
    }
    if ($switches.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Le fichier est vide.", "Erreur", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return $null
    }
    return $switches
}

# Fonction pour afficher la boîte de connexion SSH
function Show-LoginDialog {
    [xml]$xaml = @"
<Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Connexion SSH" Height="200" Width="320" WindowStartupLocation="CenterScreen">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <Label Content="Nom d'utilisateur :" Grid.Row="0" Grid.Column="0" Margin="5"/>
        <TextBox Name="textUser" Grid.Row="0" Grid.Column="1" Margin="5"/>

        <Label Content="Mot de passe :" Grid.Row="1" Grid.Column="0" Margin="5"/>
        <PasswordBox Name="textPass" Grid.Row="1" Grid.Column="1" Margin="5"/>

        <Label Content="Mot de passe super :" Grid.Row="2" Grid.Column="0" Margin="5"/>
        <PasswordBox Name="textSuperPass" Grid.Row="2" Grid.Column="1" Margin="5"/>

        <StackPanel Grid.Row="3" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Center" Margin="5">
            <Button Name="buttonOK" Content="Connexion" Width="80" Margin="5"/>
            <Button Name="buttonCancel" Content="Annuler" Width="80" Margin="5"/>
        </StackPanel>
    </Grid>
</Window>
"@
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $loginForm = [Windows.Markup.XamlReader]::Load($reader)
    if ($null -eq $window) {
        Write-Host "Erreur : Impossible de charger l'interface graphique. Verifiez le fichier interface.xaml."
        exit
    }

    # Récupérer les contrôles
    $buttonOK = $loginForm.FindName("buttonOK")
    $buttonCancel = $loginForm.FindName("buttonCancel")
    $textUser = $loginForm.FindName("textUser")
    $textPass = $loginForm.FindName("textPass")
    $textSuperPass = $loginForm.FindName("textSuperPass")

    if (-not $buttonOK -or -not $buttonCancel -or -not $textUser -or -not $textPass -or -not $textSuperPass) {
        Write-Host "Erreur : Un ou plusieurs champs du formulaire de connexion sont introuvables."
        exit
    }

    $buttonOK.Add_Click({
        $loginForm.Tag = @{
            Username = $textUser.Text
            Password = $textPass.Password
            SuperPassword = $textSuperPass.Password
        }
        $loginForm.Close()
    })

    $buttonCancel.Add_Click({
        $loginForm.Tag = $null
        $loginForm.Close()
    })

    $loginForm.ShowDialog() | Out-Null
    return $loginForm.Tag
}

# Charger le fichier XAML
[xml]$xaml = Get-Content -Path "interface.xaml"
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Récupérer les éléments de l'interface
$searchBox = $window.FindName("SearchBox")
$switchList = $window.FindName("SwitchList")
$commandBox = $window.FindName("CommandBox")
$connectButton = $window.FindName("ConnectButton")
$disconnectButton = $window.FindName("DisconnectButton")
$sendCommandButton = $window.FindName("SendCommandButton")
$resultTextBox = $window.FindName("ResultTextBox")
$clearSearchButton = $window.FindName("ClearSearchButton")
$moreHandlingCheckBox = $window.FindName("MoreHandlingCheckBox")


# Vérification après récupération
if (-not $switchList -or -not $searchBox -or -not $connectButton -or -not $disconnectButton -or -not $sendCommandButton -or -not $resultTextBox) {
    Write-Host "Erreur : Un ou plusieurs elements de l'interface sont introuvables."
    exit
}

# Mise à jour dynamique de la liste et gestion d'affichage de la croix
$searchBox.Add_TextChanged({
    $searchText = $searchBox.Text

    # Afficher ou masquer la croix en fonction du contenu
    if ([string]::IsNullOrWhiteSpace($searchText) -or $searchText -eq "Rechercher un switch...") {
        $clearSearchButton.Visibility = 'Collapsed'
    } else {
        $clearSearchButton.Visibility = 'Visible'
    }

    # Filtrage des switches selon la recherche
    $switchList.Items.Clear()
    foreach ($switch in $switches) {
        if ("$($switch.Name) - $($switch.Hostname)" -like "*$searchText*") {
            $switchList.Items.Add("$($switch.Name) - $($switch.Hostname)")
        }
    }
})

# Clic sur le bouton croix : efface le champ de recherche et masque le bouton
$clearSearchButton.Add_Click({
    $searchBox.Text = ""
    $clearSearchButton.Visibility = 'Collapsed'
})

# Charger les switches
$switches = Load-Switches
foreach ($switch in $switches) {
    $switchList.Items.Add("$($switch.Name) - $($switch.Hostname)")
}
if ($null -eq $switches -or $switches.Count -eq 0) {
    Write-Host "Erreur : Aucun switch charge depuis le fichier CSV."
    exit
}

# Placeholder de la barre de recherche
$searchBox.Text = "Rechercher un switch..."
$searchBox.Foreground = [System.Windows.Media.Brushes]::Gray

$searchBox.Add_GotFocus({
    if ($searchBox.Text -eq "Rechercher un switch...") {
        $searchBox.Text = ""
        $searchBox.Foreground = [System.Windows.Media.Brushes]::White
    }
})

$searchBox.Add_LostFocus({
    if ([string]::IsNullOrWhiteSpace($searchBox.Text)) {
        $searchBox.Text = "Rechercher un switch..."
        $searchBox.Foreground = [System.Windows.Media.Brushes]::Gray
    }
})

# Recherche dynamique
$searchBox.Add_TextChanged({
    $searchText = $searchBox.Text
    $switchList.Items.Clear()
    foreach ($switch in $switches) {
        if ("$($switch.Name) - $($switch.Hostname)" -like "*$searchText*") {
            $switchList.Items.Add("$($switch.Name) - $($switch.Hostname)")
        }
    }
})

# Connexion SSH
$connectButton.Add_Click({
    $selectedSwitch = $switchList.SelectedItem
    if ($selectedSwitch -ne $null) {
        $switchName, $switchIP = $selectedSwitch -split ' - '
        $resultTextBox.AppendText("Nom du switch : $switchName`r`nAdresse IP : $switchIP`r`n")
        $resultTextBox.AppendText("-----------------------------------------------------------`r`n")
        if ($global:session -eq $null) {
            $credentials = Show-LoginDialog
            if ($credentials -ne $null) {
                try {
                    $securePassword = ConvertTo-SecureString $credentials.Password -AsPlainText -Force
                    $credential = New-Object System.Management.Automation.PSCredential $credentials.Username, $securePassword

                    $global:session = New-SSHSession -ComputerName $switchIP -Credential $credential -ErrorAction Stop
                    $global:stream = New-SSHShellStream -SessionId $global:session.SessionId

                    Start-Sleep -Seconds 2
                    $global:stream.WriteLine("super")
                    Start-Sleep -Seconds 1
                    $global:stream.WriteLine($credentials.SuperPassword)
                    Start-Sleep -Seconds 1

                    $resultTextBox.AppendText("Connexion reussie.`r`n")

                    $global:stream.WriteLine("sys")
                    $resultTextBox.AppendText("Mode sys active.`r`n")
                    $resultTextBox.AppendText("-----------------------------------------------------------`r`n")
                    Start-Sleep -Seconds 1
                } catch {
                    $resultTextBox.AppendText("Erreur de connexion SSH : $_`r`n")
                }
            }
        }
    }
})

# Déconnexion SSH
$disconnectButton.Add_Click({
    if ($global:session -ne $null) {
        Remove-SSHSession -SessionId $global:session.SessionId -ErrorAction Stop
        $resultTextBox.AppendText("Deconnexion SSH reussie.`r`n")
        $global:session = $null
        $global:stream = $null
    }
})

# Bouton pour effacer la sortie
$clearOutputButton = $window.FindName("ClearOutputButton")
$clearOutputButton.Add_Click({
    $resultTextBox.Clear()
})

# Exécution de commande avec ou sans gestion du "-- More --"
$sendCommandButton.Add_Click({
    if ($global:session -eq $null) {
        [System.Windows.MessageBox]::Show("Vous n'etes pas connecte a un switch !", "Erreur", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    if ($global:session -ne $null -and $commandBox.SelectedItem -ne $null) {
        $selectedCommand = [string]$commandBox.SelectedItem.Content
        $resultTextBox.AppendText("Commande executee : $selectedCommand`r`n")
        $global:stream.WriteLine($selectedCommand)
        Start-Sleep -Seconds 1

        $output = ""
        $handleMore = $moreHandlingCheckBox.IsChecked -eq $true

        do {
            Start-Sleep -Milliseconds 500
            $tempOutput = $global:stream.Read()
            $output += $tempOutput

            if ($handleMore -and $tempOutput -match "---- More ----") {
                if ($selectedCommand -eq "display logbuffer reverse") {
                    $global:stream.Write(" ")
                    Start-Sleep -Milliseconds 500
                    break
                } else {
                    $global:stream.Write(" ")
                    Start-Sleep -Milliseconds 500
                }
            } else {
                break  # On sort si --more-- n'est pas géré
            }
        } while ($handleMore -and $tempOutput -match "---- More ----")

        $resultTextBox.AppendText("Resultat :`r`n$output`r`n")
        $resultTextBox.AppendText("-----------------------------------------------------------`r`n")
        $resultTextBox.ScrollToEnd()
    }
})


# Afficher la fenêtre

$window.ShowDialog()
