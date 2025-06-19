Parfait ! Voici votre `README.md` finalisé avec le nom du dépôt **Net-app**, prêt à être copié/collé dans votre GitHub :

---

````markdown
# Net-app — Interface graphique PowerShell pour la gestion de switchs via SSH

## 📖 Présentation

**Net-app** est une application PowerShell avec interface graphique permettant de :

- Charger dynamiquement une liste de switchs depuis un fichier CSV.
- Rechercher un switch par nom ou adresse IP via une barre interactive.
- Se connecter à un switch en SSH avec des identifiants manuels ou sécurisés.
- Exécuter des commandes prédéfinies depuis une liste déroulante.
- Gérer ou ignorer les sorties paginées (`---- More ----`) via une case à cocher.
- Lire les résultats dans une console intégrée à l’interface.

L’interface est construite en **WPF (XAML)** et repose sur les modules PowerShell suivants :

- [`Posh-SSH`](https://www.powershellgallery.com/packages/Posh-SSH)
- [`CredentialManager`](https://www.powershellgallery.com/packages/CredentialManager) (optionnel mais recommandé en entreprise)

---

## 📁 Contenu du dépôt

| Fichier                | Description                                               |
|------------------------|-----------------------------------------------------------|
| `app.ps1`              | Script principal à exécuter                               |
| `interface.xaml`       | Fichier XAML définissant l’interface utilisateur          |
| `liste_addr_ex.csv`    | Exemple de fichier d’adresses IP de switchs (à adapter)   |

---

## 🔧 Prérequis

Avant de lancer l’application, veuillez vous assurer que votre environnement remplit les conditions suivantes :

- **PowerShell 5.1 ou PowerShell Core 7+**
- **Modules requis :**

```powershell
Install-Module -Name Posh-SSH -Force
Install-Module -Name CredentialManager -Force  # (facultatif)
````

* **Autoriser les scripts locaux (si besoin) :**

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 📄 Format du fichier `liste_addr.csv`

Le fichier CSV d’adresses doit respecter le format suivant :

```csv
Name;Hostname
SW01;192.168.1.10
SW02;192.168.1.11
```

* **Name** : nom ou identifiant du switch.
* **Hostname** : adresse IP ou FQDN pour la connexion.

📌 Le fichier `liste_addr_ex.csv` est fourni uniquement à titre d’exemple.

---

## ▶️ Lancement de l'application

Depuis PowerShell, exécutez :

```powershell
.\app.ps1
```

L’interface graphique se lance automatiquement.

---

## 🔐 Authentification SSH

### Mode manuel (par défaut)

Une boîte de dialogue s’ouvre vous invitant à saisir :

* Le nom d’utilisateur SSH
* Le mot de passe
* Le mot de passe `super` (envoyé après connexion)

### Mode sécurisé (recommandé en entreprise)

Vous pouvez stocker les identifiants dans le **Credential Manager** Windows :

```powershell
New-StoredCredential -Target "NetApp_SSH" -Username "admin" -Password "MotDePasse!" -Persist LocalMachine
```

Puis adapter le script pour les utiliser automatiquement.

---

## ⚙️ Fonctionnalités de l'interface

* **Recherche instantanée** avec une croix pour effacer rapidement le champ.
* **Liste déroulante de commandes SSH** fréquemment utilisées.
* **CheckBox "Gérer --more--"** pour activer ou désactiver la gestion des pages interactives SSH.
* **Zone de sortie** affichant les résultats, avec défilement automatique.

---

## 🧩 Personnalisation

* Vous pouvez modifier les commandes dans le fichier `interface.xaml` sous les balises `<ComboBoxItem>`.
* La disposition et les couleurs sont entièrement personnalisables via XAML.
* L’ensemble du script PowerShell peut être adapté à d'autres environnements réseau.

---

## 💡 Améliorations possibles

* Historique des commandes envoyées.
* Connexions simultanées à plusieurs équipements.
* Export automatique des résultats au format `.txt` ou `.csv`.

---

## ❓ Support

En cas de problème :

* Assurez-vous que le fichier `liste_addr.csv` est bien structuré et présent dans le dossier du script.
* Exécutez PowerShell avec des droits administrateur si vous rencontrez des erreurs d’accès aux modules.
* Consultez la documentation de `Posh-SSH` pour toute erreur de connexion.

---

## 📅 Version

**Net-app v1.0** — Dernière mise à jour : juin 2025
Développé pour un usage en environnement professionnel Windows.
