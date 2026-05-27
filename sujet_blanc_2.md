# Examen Blanc n°2 — Bloc 2 RNCP Data Engineer
## Thème : Énergie — Consommation Électrique de Bâtiments

---

> **Contexte général**
>
> La société **ÉnerGY** exploite un parc de compteurs intelligents installés dans des bâtiments d'une grande région. Vous disposez d'un fichier de données brutes au format JSON (`releves.json`) contenant les relevés de consommation électrique collectés sur une période de plusieurs mois. Ce fichier contient des données imparfaites (valeurs manquantes, colonnes catégorielles, doublons).
>
> Votre mission est de construire un pipeline de données complet : exploration, transformation, stockage en base de données relationnelle, et entraînement d'un modèle de machine learning pour **prédire la consommation électrique d'un relevé** (en kWh).

---

> **Rendu attendu**
>
> À la fin de l'examen, votre dossier devra contenir :
> - `exploration.ipynb` — Notebook d'exploration des données
> - `transform.py` — Script d'extraction et transformation
> - `create_db.py` — Script de création de la base de données via ORM
> - `ingest.py` — Script d'ingestion des données dans la base
> - `train_model.py` — Script d'entraînement du modèle ML
> - `architecture.md` — Fichier de synthèse sur vos choix techniques
> - `.env` — Fichier de variables d'environnement
> - `docker-compose.yml` — Fichier de démarrage des services

---

## Partie 1 — Exploration de données JSON avec Jupyter

Le fichier `releves.json` contient une liste de relevés. Voici un extrait représentatif :

```json
[
  {
    "releve_id": "R001",
    "batiment": "Tour Horizon",
    "type_batiment": "bureau",
    "compteur_id": "C042",
    "consommation_kwh": 145.8,
    "surface_m2": 320.0,
    "temperature_ext_c": 8.5,
    "heure_releve": "08:00",
    "jour_semaine": "lundi",
    "source_energie": "réseau"
  },
  {
    "releve_id": "R002",
    "batiment": "Résidence Les Tilleuls",
    "type_batiment": "résidentiel",
    "compteur_id": "C017",
    "consommation_kwh": null,
    "surface_m2": null,
    "temperature_ext_c": 12.3,
    "heure_releve": "13:00",
    "jour_semaine": "mercredi",
    "source_energie": "solaire"
  }
]
```

**Questions :**

1.1. Créez un notebook `exploration.ipynb`. Importez le fichier `releves.json` avec la librairie `json` de Python et chargez-le dans un DataFrame pandas. Affichez les 5 premières lignes.

1.2. Affichez le nombre total de relevés, la liste des colonnes et le type de chaque colonne (utilisez `.info()`).

1.3. Affichez le nombre de valeurs manquantes par colonne (utilisez `.isnull().sum()`).

1.4. Affichez les statistiques descriptives des colonnes numériques (utilisez `.describe()`).

1.5. Identifiez et affichez les lignes dupliquées (même `releve_id`). Combien y en a-t-il ?

---

## Partie 2 — Développement d'un script Python structuré

Vous allez créer le fichier `transform.py` qui reprend les traitements du notebook sous forme de fonctions réutilisables.

**Questions :**

2.1. Créez une fonction `charger_donnees(chemin_fichier)` qui charge le fichier JSON et retourne un DataFrame pandas.

2.2. Créez une fonction `nettoyer_donnees(df)` qui effectue les opérations suivantes :
- Supprime les lignes dupliquées (sur la colonne `releve_id`)
- Supprime les lignes où `consommation_kwh` est manquante (c'est notre variable cible)
- Retourne le DataFrame nettoyé

2.3. Créez une fonction `main()` qui appelle les deux fonctions précédentes dans l'ordre, affiche la forme du DataFrame avant et après nettoyage, et sauvegarde le résultat dans un fichier `releves_propres.csv`.

2.4. Assurez-vous que le script s'exécute uniquement quand il est lancé directement (utilisez le bloc `if __name__ == "__main__"`).

---

## Partie 3 — Manipulation avec pandas et matplotlib

Dans votre notebook `exploration.ipynb`, ajoutez une nouvelle section "Visualisations".

**Questions :**

3.1. Calculez et affichez la consommation moyenne par `type_batiment` (utilisez `.groupby()`).

3.2. Tracez un histogramme de la distribution de la colonne `consommation_kwh` avec matplotlib. Ajoutez un titre, un label sur l'axe X et un label sur l'axe Y.

3.3. Tracez un graphique en barres montrant le nombre de relevés par `jour_semaine`. Ordonnez les jours de la semaine du lundi au dimanche.

3.4. Tracez un nuage de points (`scatter plot`) avec `surface_m2` en abscisse et `consommation_kwh` en ordonnée. Colorez les points selon le `type_batiment`.

---

## Partie 4 — Gestion des valeurs manquantes et colonnes catégorielles

Dans `transform.py`, enrichissez la fonction `nettoyer_donnees(df)` avec les traitements suivants.

**Questions :**

4.1. Remplacez les valeurs manquantes de la colonne `temperature_ext_c` par la **médiane** de cette colonne.

4.2. Remplacez les valeurs manquantes de la colonne `surface_m2` par la **moyenne** de cette colonne.

4.3. Encodez la colonne `source_energie` en valeurs numériques : `"réseau"` → `0`, `"solaire"` → `1`. Créez une nouvelle colonne `source_energie_encode` pour stocker ce résultat (n'écrasez pas la colonne originale).

4.4. Encodez la colonne `jour_semaine` avec `pd.get_dummies()` et concaténez les nouvelles colonnes au DataFrame. Supprimez la colonne `jour_semaine` originale.

---

## Partie 5 — Base de données relationnelle avec Docker et phpMyAdmin

**Questions :**

5.1. Créez un fichier `.env` contenant les variables suivantes :
```
MYSQL_ROOT_PASSWORD=rootpass
MYSQL_DATABASE=energydb
MYSQL_USER=energyuser
MYSQL_PASSWORD=energypass
DB_HOST=localhost
DB_PORT=3306
```

5.2. Créez un fichier `docker-compose.yml` qui lance deux services :
- Un service `db` basé sur l'image `mysql:8.0`, qui utilise les variables du fichier `.env` et monte un volume `mysql_data` pour la persistance des données. Le port `3306` doit être exposé.
- Un service `phpmyadmin` basé sur l'image `phpmyadmin/phpmyadmin`, accessible sur le port `8080`, connecté au service `db`.

5.3. Lancez les services avec la commande appropriée et vérifiez que phpMyAdmin est accessible sur `http://localhost:8080`. Décrivez en quelques lignes dans `architecture.md` les étapes que vous avez suivies.

---

## Partie 6 — Variables d'environnement dans Docker et Python

**Questions :**

6.1. Dans `docker-compose.yml`, modifiez le service `db` pour qu'il charge ses variables d'environnement depuis le fichier `.env` en utilisant la directive `env_file`.

6.2. Dans `create_db.py`, utilisez la librairie `python-dotenv` pour charger les variables du fichier `.env`. Construisez la chaîne de connexion à la base de données sous la forme :
```
mysql+pymysql://<user>:<password>@<host>:<port>/<database>
```
Affichez la chaîne de connexion (sans le mot de passe) pour vérification.

---

## Partie 7 — Architecture de la base de données relationnelle

La base de données `energydb` doit contenir les trois tables suivantes. Vous trouverez ci-dessous le schéma logique à implémenter.

```
BATIMENTS
---------
batiment_id   INT (PK, auto-increment)
nom           VARCHAR(100)
type_batiment VARCHAR(50)

COMPTEURS
---------
compteur_id   VARCHAR(10) (PK)
source_energie VARCHAR(20)

RELEVES
-------
releve_id          VARCHAR(10) (PK)
batiment_id        INT (FK → BATIMENTS.batiment_id)
compteur_id        VARCHAR(10) (FK → COMPTEURS.compteur_id)
consommation_kwh   FLOAT
surface_m2         FLOAT
temperature_ext_c  FLOAT
heure_releve       VARCHAR(10)
jour_semaine       VARCHAR(20)
```

**Questions :**

7.1. Sur papier ou dans `architecture.md`, listez les clés primaires et étrangères de ce schéma. Expliquez pourquoi `type_batiment` est stocké dans la table `BATIMENTS` et non dans `RELEVES`.

7.2. Expliquez en quelques phrases la différence entre une clé primaire et une clé étrangère, et pourquoi ce type de schéma est dit "relationnel".

---

## Partie 8 — Interfaçage SQL avec SQLAlchemy ORM

Dans le fichier `create_db.py`, implémentez le schéma de la Partie 7 avec SQLAlchemy ORM.

**Questions :**

8.1. Créez les trois classes ORM (`Batiment`, `Compteur`, `Releve`) qui correspondent aux tables du schéma. Utilisez `declarative_base()` de SQLAlchemy.

8.2. Créez le moteur SQLAlchemy (`create_engine`) en utilisant la chaîne de connexion construite en Partie 6. Puis appelez `Base.metadata.create_all(engine)` pour créer les tables dans la base.

8.3. Vérifiez via phpMyAdmin que les trois tables ont bien été créées avec les bons types et les bonnes contraintes.

---

## Partie 9 — Entraînement d'un modèle de machine learning

Dans le fichier `train_model.py`, vous allez entraîner un modèle pour **prédire la consommation électrique** (`consommation_kwh`).

**Questions :**

9.1. Chargez le fichier `releves_propres.csv` généré en Partie 2. Sélectionnez les colonnes suivantes comme **features** (variables d'entrée) :
```
surface_m2, temperature_ext_c, source_energie_encode,
jour_semaine_lundi, jour_semaine_mardi, jour_semaine_mercredi,
jour_semaine_jeudi, jour_semaine_vendredi, jour_semaine_samedi, jour_semaine_dimanche
```
La variable cible est `consommation_kwh`.

9.2. Séparez les données en un jeu d'entraînement (80%) et un jeu de test (20%) avec `train_test_split` de scikit-learn. Fixez `random_state=42`.

9.3. Entraînez un modèle `RandomForestRegressor` avec les paramètres par défaut sur le jeu d'entraînement.

---

## Partie 10 — Évaluation et sauvegarde du modèle

**Questions :**

10.1. Calculez et affichez les métriques suivantes sur le jeu de test :
- **MAE** (Mean Absolute Error)
- **RMSE** (Root Mean Squared Error)
- **R²** (coefficient de détermination)

10.2. Affichez les 5 variables les plus importantes selon le modèle (`feature_importances_`).

10.3. Sauvegardez le modèle entraîné dans un fichier `modele_energy.joblib` avec la librairie `joblib`. Rechargez-le immédiatement et faites une prédiction de test sur la première ligne du jeu de test pour vérifier.

---

## Partie 11 — Environnement de production avec docker-compose

Vous allez enrichir votre `docker-compose.yml` pour y ajouter un service Python qui exécute automatiquement l'ingestion des données au démarrage.

**Questions :**

11.1. Créez un `Dockerfile` pour votre application Python avec les étapes suivantes :
- Image de base : `python:3.11-slim`
- Copie du fichier `requirements.txt` et installation des dépendances
- Copie du reste du code
- Commande par défaut : `python ingest.py`

11.2. Ajoutez un service `app` dans `docker-compose.yml` qui :
- Build l'image depuis le `Dockerfile`
- Dépend du service `db` (`depends_on`)
- Charge les variables depuis le fichier `.env`

11.3. Décrivez dans `architecture.md` pourquoi `depends_on` ne garantit pas que MySQL est prêt à accepter des connexions, et comment on pourrait gérer ce problème (ex: boucle de retry, `healthcheck`).

---

## Partie 12 — Ingestion complète et robuste

Dans le fichier `ingest.py`, vous allez implémenter l'ingestion complète des données dans les trois tables (`BATIMENTS`, `COMPTEURS`, `RELEVES`) dans le bon ordre, avec des contrôles de robustesse.

> **Rappel important :** la table `RELEVES` contient des clés étrangères vers `BATIMENTS` et `COMPTEURS`. Vous devez donc impérativement peupler ces deux tables **avant** d'insérer les relevés, sous peine d'erreur d'intégrité référentielle MySQL.

---

### Étape A — Peuplement de la table BATIMENTS

12.1. Créez une fonction `inserer_batiments(df, session)` qui :
- Collecte tous les bâtiments uniques présents dans le DataFrame. Comme un bâtiment a un `nom` et un `type_batiment`, regroupez sur le couple `(batiment, type_batiment)` (ignorez les valeurs nulles avec `.dropna()`)
- Pour chaque bâtiment, vérifie s'il existe déjà en base (requête `filter_by` sur le nom) — si oui, ne l'insère pas
- Insère les nouveaux bâtiments dans la table `BATIMENTS` et appelle `session.commit()` après chaque insertion
- Retourne un dictionnaire Python de la forme `{ "Tour Horizon": 1, "Résidence Les Tilleuls": 2, ... }` qui associe chaque nom de bâtiment à son `batiment_id` généré par la base

> **Indice :** après un `session.commit()`, SQLAlchemy renseigne automatiquement l'attribut `batiment_id` de l'objet inséré grâce à l'auto-increment. Vous pouvez donc l'utiliser directement pour construire le dictionnaire.

---

### Étape B — Peuplement de la table COMPTEURS

12.2. Créez une fonction `inserer_compteurs(df, session)` qui :
- Collecte tous les couples uniques `(compteur_id, source_energie)` présents dans le DataFrame
- Pour chaque compteur, vérifie s'il existe déjà en base avant de l'insérer
- Insère les nouveaux compteurs dans la table `COMPTEURS` (en conservant leur `source_energie`)
- Appelle `session.commit()` une seule fois après toutes les insertions

---

### Étape C — Insertion des RELEVES avec robustesse

12.3. Créez une fonction `valider_ligne(ligne)` qui lève une `ValueError` explicite si l'une des colonnes obligatoires (`releve_id`, `consommation_kwh`, `surface_m2`) est nulle ou manquante.

12.4. Créez une fonction `inserer_releves(df, session, mapping_batiments)` qui parcourt le DataFrame ligne par ligne et, pour chaque ligne :
- Appelle `valider_ligne()` en premier
- Vérifie qu'aucun relevé avec le même `releve_id` n'existe déjà en base — si doublon détecté, affiche un message et passe à la ligne suivante
- Résout l'identifiant du bâtiment en utilisant le dictionnaire `mapping_batiments` reçu en paramètre (ex : `mapping_batiments.get("Tour Horizon")` → `1`)
- Reconstruit la valeur textuelle du `jour_semaine` à partir des colonnes one-hot créées en Partie 4 (`jour_semaine_lundi`, `jour_semaine_mardi`, etc.) — la colonne `jour_semaine` originale n'existe plus dans `releves_propres.csv`
- Crée un objet `Releve` complet avec tous les champs du schéma (y compris `batiment_id`, `compteur_id`, `jour_semaine`)
- Gère les erreurs avec un double bloc `try/except` : un `except ValueError` pour les erreurs de validation, un `except Exception` pour les erreurs SQLAlchemy (avec `session.rollback()`)
- Affiche en fin d'exécution le nombre de relevés insérés, de doublons ignorés et d'erreurs

12.5. Créez une fonction `main()` qui :
- Charge `releves_propres.csv` dans un DataFrame
- Ouvre une session SQLAlchemy
- Appelle les trois fonctions dans le bon ordre : `inserer_batiments`, puis `inserer_compteurs`, puis `inserer_releves`
- Ferme la session proprement

Assurez-vous que le script s'exécute uniquement quand il est lancé directement (bloc `if __name__ == "__main__"`).

---

## Partie 13 — Impact écologique du projet

**Questions :**

13.1. Faites une recherche sur le site **Green Algorithms** (https://www.green-algorithms.org/) ou tout autre outil en ligne. Estimez la consommation énergétique (en kWh) et les émissions de CO₂ (en gCO₂eq) de votre entraînement de modèle, en supposant les paramètres suivants :
- Durée d'exécution : 10 minutes
- 1 CPU standard
- Localisation : France

13.2. Dans `architecture.md`, notez les valeurs obtenues et proposez **deux actions concrètes** pour réduire l'empreinte carbone d'un projet data en production (ex : choix du datacenter, optimisation du modèle, etc.).
