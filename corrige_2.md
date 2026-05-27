# Corrigé — Examen Blanc n°2 Bloc 2 RNCP Data Engineer
## Thème : Énergie — Consommation Électrique de Bâtiments

---

## Partie 1 — Exploration de données JSON avec Jupyter

### 1.1 — Charger le JSON dans un DataFrame

```python
import json
import pandas as pd

# Ouverture et lecture du fichier JSON
with open("releves.json", "r", encoding="utf-8") as f:
    donnees = json.load(f)

# Conversion en DataFrame
df = pd.DataFrame(donnees)

# Affichage des 5 premières lignes
df.head()
```

> **Explication :** On utilise la librairie standard `json` pour lire le fichier, puis `pd.DataFrame()` pour convertir la liste de dictionnaires en tableau. `json.load()` lit le fichier entier en mémoire — c'est adapté pour des fichiers de taille raisonnable.

---

### 1.2 — Nombre de relevés, colonnes et types

```python
# Nombre total de lignes
print("Nombre de relevés :", len(df))

# Colonnes, types et valeurs non-nulles
df.info()
```

> **Explication :** `len(df)` retourne le nombre de lignes. `.info()` affiche en une seule commande les noms de colonnes, leur type (`dtype`) et le nombre de valeurs non-nulles.

---

### 1.3 — Valeurs manquantes par colonne

```python
# Nombre de NaN par colonne
print(df.isnull().sum())
```

> **Explication :** `.isnull()` crée un DataFrame de booléens (True si la valeur est manquante), et `.sum()` additionne les True de chaque colonne. On obtient le compte exact de valeurs manquantes colonne par colonne.

---

### 1.4 — Statistiques descriptives

```python
# Statistiques (count, mean, std, min, quartiles, max) sur les colonnes numériques
df.describe()
```

> **Explication :** `.describe()` ne s'applique automatiquement qu'aux colonnes numériques. Il permet de repérer des anomalies comme des valeurs négatives impossibles ou des maximums aberrants.

---

### 1.5 — Lignes dupliquées

```python
# Lignes avec un releve_id déjà vu
doublons = df[df.duplicated(subset="releve_id", keep=False)]

print("Nombre de doublons :", len(doublons))
print(doublons)
```

> **Explication :** `df.duplicated(subset="releve_id", keep=False)` retourne True pour **toutes** les occurrences d'un `releve_id` dupliqué. `keep=False` est important : sans lui, la première occurrence ne serait pas signalée.

---

## Partie 2 — Script Python structuré

### Fichier : `transform.py`

```python
import json
import pandas as pd


def charger_donnees(chemin_fichier):
    """Charge un fichier JSON et retourne un DataFrame pandas."""
    with open(chemin_fichier, "r", encoding="utf-8") as f:
        donnees = json.load(f)
    df = pd.DataFrame(donnees)
    return df


def nettoyer_donnees(df):
    """Supprime les doublons et les lignes sans consommation."""
    # Suppression des doublons sur releve_id (on garde la première occurrence)
    df = df.drop_duplicates(subset="releve_id", keep="first")

    # Suppression des lignes où consommation_kwh est manquante (variable cible)
    df = df.dropna(subset=["consommation_kwh"])

    return df


def main():
    chemin = "releves.json"

    # Chargement
    df = charger_donnees(chemin)
    print("Forme avant nettoyage :", df.shape)

    # Nettoyage
    df_propre = nettoyer_donnees(df)
    print("Forme après nettoyage :", df_propre.shape)

    # Sauvegarde
    df_propre.to_csv("releves_propres.csv", index=False)
    print("Fichier releves_propres.csv sauvegardé.")


if __name__ == "__main__":
    main()
```

> **Explication :**
> - Chaque fonction fait une seule chose : c'est le principe de responsabilité unique.
> - `drop_duplicates` avec `keep="first"` conserve la première occurrence et supprime les suivantes.
> - `dropna(subset=["consommation_kwh"])` ne supprime que les lignes où **cette colonne précise** est nulle — pas toutes les lignes avec un NaN quelque part.
> - Le bloc `if __name__ == "__main__"` empêche `main()` de s'exécuter quand ce fichier est importé par un autre script.

---

## Partie 3 — Visualisations avec pandas et matplotlib

### 3.1 — Consommation moyenne par type de bâtiment

```python
import matplotlib.pyplot as plt

# Consommation moyenne par type de bâtiment
conso_par_type = df.groupby("type_batiment")["consommation_kwh"].mean()
print(conso_par_type)
```

> **Explication :** `.groupby("type_batiment")` regroupe les lignes par valeur unique de cette colonne, puis `["consommation_kwh"].mean()` calcule la moyenne de consommation dans chaque groupe.

---

### 3.2 — Histogramme de la consommation

```python
plt.figure(figsize=(8, 5))
plt.hist(df["consommation_kwh"].dropna(), bins=20, color="steelblue", edgecolor="white")
plt.title("Distribution de la consommation électrique")
plt.xlabel("Consommation (kWh)")
plt.ylabel("Nombre de relevés")
plt.tight_layout()
plt.show()
```

> **Explication :** On utilise `.dropna()` pour éviter les erreurs dues aux valeurs manquantes. `bins=20` découpe la plage de valeurs en 20 intervalles. `edgecolor="white"` améliore la lisibilité.

---

### 3.3 — Graphique en barres par jour de la semaine

```python
# Ordre souhaité des jours
ordre_jours = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]

# Comptage et réindexation dans le bon ordre
releves_par_jour = df["jour_semaine"].value_counts().reindex(ordre_jours)

plt.figure(figsize=(8, 5))
plt.bar(releves_par_jour.index, releves_par_jour.values, color="coral")
plt.title("Nombre de relevés par jour de la semaine")
plt.xlabel("Jour")
plt.ylabel("Nombre de relevés")
plt.tight_layout()
plt.show()
```

> **Explication :** `value_counts()` trie par fréquence décroissante par défaut. `.reindex(ordre_jours)` force l'ordre chronologique souhaité. Les valeurs absentes deviennent NaN (affichées à 0 dans le graphique).

---

### 3.4 — Nuage de points surface vs consommation

```python
# Séparer les types pour la coloration
bureaux = df[df["type_batiment"] == "bureau"]
residentiels = df[df["type_batiment"] == "résidentiel"]
commerces = df[df["type_batiment"] == "commerce"]

plt.figure(figsize=(8, 5))
plt.scatter(bureaux["surface_m2"], bureaux["consommation_kwh"], label="Bureau", alpha=0.6, color="steelblue")
plt.scatter(residentiels["surface_m2"], residentiels["consommation_kwh"], label="Résidentiel", alpha=0.6, color="coral")
plt.scatter(commerces["surface_m2"], commerces["consommation_kwh"], label="Commerce", alpha=0.6, color="green")
plt.title("Surface vs Consommation électrique")
plt.xlabel("Surface (m²)")
plt.ylabel("Consommation (kWh)")
plt.legend()
plt.tight_layout()
plt.show()
```

> **Explication :** On filtre le DataFrame en plusieurs sous-DataFrames pour attribuer une couleur différente à chaque type. `alpha=0.6` rend les points semi-transparents, ce qui aide à voir les zones denses.

---

## Partie 4 — Gestion des valeurs manquantes et catégorielles

### Fonction `nettoyer_donnees` complète dans `transform.py`

```python
def nettoyer_donnees(df):
    """Nettoyage complet : doublons, NaN, encodages."""

    # Suppression des doublons
    df = df.drop_duplicates(subset="releve_id", keep="first")

    # Suppression des lignes sans consommation (variable cible indispensable)
    df = df.dropna(subset=["consommation_kwh"])

    # 4.1 — Remplacement des NaN de temperature_ext_c par la médiane
    mediane_temp = df["temperature_ext_c"].median()
    df["temperature_ext_c"] = df["temperature_ext_c"].fillna(mediane_temp)

    # 4.2 — Remplacement des NaN de surface_m2 par la moyenne
    moyenne_surface = df["surface_m2"].mean()
    df["surface_m2"] = df["surface_m2"].fillna(moyenne_surface)

    # 4.3 — Encodage binaire de source_energie
    df["source_energie_encode"] = df["source_energie"].apply(
        lambda x: 1 if x == "solaire" else 0
    )

    # 4.4 — Encodage one-hot de jour_semaine
    dummies = pd.get_dummies(df["jour_semaine"], prefix="jour_semaine")
    df = pd.concat([df, dummies], axis=1)
    df = df.drop(columns=["jour_semaine"])

    return df
```

> **Explication :**
> - On utilise la **médiane** pour `temperature_ext_c` (moins sensible aux valeurs extrêmes) et la **moyenne** pour `surface_m2` (comme demandé dans l'énoncé — les deux méthodes sont valables selon le contexte).
> - `.apply(lambda x: ...)` applique une fonction ligne par ligne — c'est la façon la plus lisible pour un encodage binaire simple. Ici `"solaire"` → 1, tout le reste (dont `"réseau"`) → 0.
> - `pd.get_dummies()` crée une colonne binaire (0/1) par valeur unique de `jour_semaine`. Le préfixe `jour_semaine_` évite les conflits de noms.
> - `pd.concat(..., axis=1)` ajoute les nouvelles colonnes à droite du DataFrame existant.

---

## Partie 5 — Docker et phpMyAdmin

### 5.1 — Fichier `.env`

```env
MYSQL_ROOT_PASSWORD=rootpass
MYSQL_DATABASE=energydb
MYSQL_USER=energyuser
MYSQL_PASSWORD=energypass
DB_HOST=localhost
DB_PORT=3306
```

> **Explication :** Ce fichier centralise toutes les configurations sensibles. Il ne doit **jamais** être commité dans Git — ajoutez `.env` à votre `.gitignore`.

---

### 5.2 — Fichier `docker-compose.yml`

```yaml
version: "3.8"

services:

  db:
    image: mysql:8.0
    env_file:
      - .env
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    ports:
      - "8080:80"
    environment:
      PMA_HOST: db
      PMA_PORT: 3306
    depends_on:
      - db

volumes:
  mysql_data:
```

> **Explication :**
> - Le volume `mysql_data` assure que les données survivent à un `docker-compose down`.
> - `PMA_HOST: db` indique à phpMyAdmin de se connecter au service nommé `db` (Docker résout les noms de services comme des hostnames sur le réseau interne).
> - `depends_on` garantit que le conteneur `db` démarre **avant** phpMyAdmin — mais ne garantit pas que MySQL est prêt à accepter des connexions (voir Partie 11).

**Commande pour démarrer :**
```bash
docker-compose up -d
```
Si container déjà exixtant :
Pour lister les conteneurs existants :
`docker ps -a`

Pour supprimer le conteneur en conflit :
`docker rm -f mysqldb`

Puis relancez docker compose up.
---

## Partie 6 — Variables d'environnement en Python

### 6.1 — `env_file` dans docker-compose

Déjà intégré dans le `docker-compose.yml` ci-dessus avec `env_file: - .env`.

---

### 6.2 — Chargement dans `create_db.py`

```python
import os
from dotenv import load_dotenv

# Chargement du fichier .env
load_dotenv()

# Lecture des variables
user = os.getenv("MYSQL_USER")
password = os.getenv("MYSQL_PASSWORD")
host = os.getenv("DB_HOST")
port = os.getenv("DB_PORT")
database = os.getenv("MYSQL_DATABASE")

# Construction de la chaîne de connexion
DATABASE_URL = f"mysql+pymysql://{user}:{password}@{host}:{port}/{database}"

# Affichage sans le mot de passe
print(f"Connexion à : mysql+pymysql://{user}:***@{host}:{port}/{database}")
```

> **Explication :**
> - `load_dotenv()` lit le fichier `.env` et injecte les variables dans l'environnement du processus Python.
> - `os.getenv()` lit ensuite ces variables. Si une variable est absente, il retourne `None` au lieu de lever une erreur.
> - On n'affiche jamais le mot de passe dans les logs — on le remplace par `***`.

---

## Partie 7 — Architecture de la base de données

### 7.1 — Clés primaires et étrangères

| Table     | Clé primaire   | Clés étrangères                                          |
|-----------|----------------|----------------------------------------------------------|
| BATIMENTS | `batiment_id`  | —                                                        |
| COMPTEURS | `compteur_id`  | —                                                        |
| RELEVES   | `releve_id`    | `batiment_id` → BATIMENTS, `compteur_id` → COMPTEURS     |

`type_batiment` est stocké dans la table `BATIMENTS` et non dans `RELEVES` parce que c'est une **propriété du bâtiment**, pas du relevé. Un même bâtiment peut avoir des dizaines de relevés ; si on stockait son type dans chaque relevé, on dupliquerait la même information des dizaines de fois (risque d'incohérence et gaspillage d'espace). C'est le principe de **normalisation** : chaque information est stockée une seule fois, à l'endroit logique.

---

### 7.2 — Clé primaire vs clé étrangère

> **Clé primaire (PK) :** identifiant unique d'une ligne dans sa propre table. Elle garantit qu'il n'existe pas deux lignes identiques.
>
> **Clé étrangère (FK) :** colonne qui fait référence à la clé primaire d'une **autre** table. Elle crée un lien entre les tables et garantit l'intégrité référentielle (on ne peut pas insérer un relevé avec un bâtiment qui n'existe pas).
>
> On parle de schéma **relationnel** parce que les données sont organisées en tables liées par ces relations. Cela évite la duplication : le nom et le type d'un bâtiment sont stockés une seule fois dans `BATIMENTS`, et tous les relevés qui en ont besoin le référencent par son `batiment_id`.

---

## Partie 8 — SQLAlchemy ORM

### Fichier complet : `create_db.py`

```python
import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, Column, Integer, String, Float, ForeignKey
from sqlalchemy.orm import declarative_base

load_dotenv()

user = os.getenv("MYSQL_USER")
password = os.getenv("MYSQL_PASSWORD")
host = os.getenv("DB_HOST")
port = os.getenv("DB_PORT")
database = os.getenv("MYSQL_DATABASE")

DATABASE_URL = f"mysql+pymysql://{user}:{password}@{host}:{port}/{database}"

# Base déclarative — toutes les classes ORM en héritent
Base = declarative_base()


# 8.1 — Définition des classes ORM
class Batiment(Base):
    __tablename__ = "batiments"

    batiment_id = Column(Integer, primary_key=True, autoincrement=True)
    nom = Column(String(100), nullable=False)
    type_batiment = Column(String(50))


class Compteur(Base):
    __tablename__ = "compteurs"

    compteur_id = Column(String(10), primary_key=True)
    source_energie = Column(String(20))


class Releve(Base):
    __tablename__ = "releves"

    releve_id = Column(String(10), primary_key=True)
    batiment_id = Column(Integer, ForeignKey("batiments.batiment_id"))
    compteur_id = Column(String(10), ForeignKey("compteurs.compteur_id"))
    consommation_kwh = Column(Float)
    surface_m2 = Column(Float)
    temperature_ext_c = Column(Float)
    heure_releve = Column(String(10))
    jour_semaine = Column(String(20))


# 8.2 — Création du moteur et des tables
engine = create_engine(DATABASE_URL, echo=True)
Base.metadata.create_all(engine)

print("Tables créées avec succès.")
```

> **Explication :**
> - `declarative_base()` crée une classe de base dont héritent toutes les tables. SQLAlchemy s'en sert pour recenser les tables à créer.
> - `ForeignKey("batiments.batiment_id")` utilise le **nom de la table SQL** (pas le nom de la classe Python).
> - `echo=True` fait afficher dans le terminal toutes les requêtes SQL générées par SQLAlchemy — très utile pour déboguer.
> - `Base.metadata.create_all(engine)` ne recrée pas les tables si elles existent déjà.

---

## Partie 9 — Entraînement du modèle ML

### Fichier : `train_model.py` (parties 9 et 10)

```python
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import joblib
import numpy as np

# 9.1 — Chargement et sélection des features
df = pd.read_csv("releves_propres.csv")

# Liste des colonnes features
colonnes_features = [
    "surface_m2",
    "temperature_ext_c",
    "source_energie_encode",
    "jour_semaine_lundi",
    "jour_semaine_mardi",
    "jour_semaine_mercredi",
    "jour_semaine_jeudi",
    "jour_semaine_vendredi",
    "jour_semaine_samedi",
    "jour_semaine_dimanche",
]

# On garde uniquement les colonnes qui existent dans le DataFrame
colonnes_presentes = [col for col in colonnes_features if col in df.columns]

X = df[colonnes_presentes]
y = df["consommation_kwh"]

# 9.2 — Séparation entraînement / test
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

print("Taille jeu d'entraînement :", len(X_train))
print("Taille jeu de test :", len(X_test))

# 9.3 — Entraînement du modèle
modele = RandomForestRegressor(random_state=42)
modele.fit(X_train, y_train)

print("Modèle entraîné.")
```

> **Explication :**
> - On filtre les colonnes features pour ne garder que celles qui existent réellement dans le CSV (certaines colonnes one-hot peuvent manquer si un jour n'apparaît pas dans les données).
> - `test_size=0.2` réserve 20% des données pour le test. `random_state=42` fixe la graine aléatoire pour que les résultats soient reproductibles.
> - `RandomForestRegressor` est un ensemble d'arbres de décision. Il gère bien les relations non-linéaires et ne nécessite pas de normalisation des données.

---

## Partie 10 — Évaluation et sauvegarde

*(suite de `train_model.py`)*

```python
# 10.1 — Métriques d'évaluation
y_pred = modele.predict(X_test)

mae = mean_absolute_error(y_test, y_pred)
rmse = np.sqrt(mean_squared_error(y_test, y_pred))
r2 = r2_score(y_test, y_pred)

print(f"MAE  : {mae:.2f} kWh")
print(f"RMSE : {rmse:.2f} kWh")
print(f"R²   : {r2:.4f}")
```

> **Explication des métriques :**
> - **MAE** : erreur moyenne en valeur absolue. Si MAE = 12.5, le modèle se trompe en moyenne de 12,5 kWh.
> - **RMSE** : similaire au MAE mais pénalise davantage les grandes erreurs (car on élève au carré).
> - **R²** : proportion de la variance expliquée par le modèle. R²=1 = parfait, R²=0 = aussi bon que de prédire la moyenne.

```python
# 10.2 — Importance des variables
importances = pd.Series(modele.feature_importances_, index=colonnes_presentes)
top5 = importances.sort_values(ascending=False).head(5)
print("\nTop 5 variables importantes :")
print(top5)
```

> **Explication :** `feature_importances_` donne le score d'importance de chaque variable (somme = 1). On crée une Series pandas pour avoir les noms de colonnes associés, puis on trie.

```python
# 10.3 — Sauvegarde et vérification
joblib.dump(modele, "modele_energy.joblib")
print("Modèle sauvegardé dans modele_energy.joblib")

# Rechargement et test
modele_recharge = joblib.load("modele_energy.joblib")
premiere_ligne = X_test.iloc[[0]]  # Double crochet pour garder le format DataFrame
prediction = modele_recharge.predict(premiere_ligne)
print(f"Prédiction de test : {prediction[0]:.2f} kWh")
print(f"Valeur réelle      : {y_test.iloc[0]:.2f} kWh")
```

> **Explication :**
> - `joblib.dump()` sérialise l'objet Python (le modèle entraîné) dans un fichier binaire.
> - `iloc[[0]]` avec **double crochet** retourne un DataFrame d'une ligne — `predict()` attend un tableau 2D, pas une Series 1D.

---

## Partie 11 — Environnement de production

### 11.1 — `Dockerfile`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Installation des dépendances d'abord (optimise le cache Docker)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copie du reste du code
COPY . .

CMD ["python", "ingest.py"]
```

**Contenu minimal de `requirements.txt` :**
```
pandas
sqlalchemy
pymysql
python-dotenv
```

> **Explication :**
> - On copie `requirements.txt` **avant** le reste du code. Ainsi, si seul le code change (pas les dépendances), Docker réutilise le cache de l'étape `pip install` — le build est plus rapide.
> - `python:3.11-slim` est une image légère (sans les outils de dev inutiles).

---

### 11.2 — Service `app` dans `docker-compose.yml`

```yaml
version: "3.8"

services:

  db:
    image: mysql:8.0
    env_file:
      - .env
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    ports:
      - "8080:80"
    environment:
      PMA_HOST: db
      PMA_PORT: 3306
    depends_on:
      - db

  app:
    build: .
    env_file:
      - .env
    depends_on:
      - db

volumes:
  mysql_data:
```

---

### 11.3 — Limites de `depends_on` (à noter dans `architecture.md`)

> `depends_on` garantit uniquement que le **conteneur** `db` a démarré — pas que le **serveur MySQL** à l'intérieur est prêt à accepter des connexions. MySQL prend plusieurs secondes à s'initialiser après le démarrage du conteneur.
>
> **Solutions possibles :**
>
> 1. **Boucle de retry dans le code Python** : tenter la connexion en boucle avec un `time.sleep(2)` jusqu'à ce qu'elle réussisse.
> 2. **`healthcheck` dans docker-compose** : définir une commande de vérification de santé sur le service `db`, et utiliser `condition: service_healthy` dans `depends_on`.

```yaml
# Exemple de healthcheck sur le service db
db:
  image: mysql:8.0
  healthcheck:
    test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
    interval: 5s
    timeout: 3s
    retries: 10

app:
  depends_on:
    db:
      condition: service_healthy
```

---

## Partie 12 — Ingestion complète et robuste

L'ingestion complète se fait en trois étapes dans l'ordre : on peuple d'abord `BATIMENTS`, puis `COMPTEURS`, puis `RELEVES` (qui dépend des deux premières via ses clés étrangères).

### Fichier complet : `ingest.py`

```python
import os
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from create_db import Batiment, Compteur, Releve  # Import des trois classes ORM

load_dotenv()

user = os.getenv("MYSQL_USER")
password = os.getenv("MYSQL_PASSWORD")
host = os.getenv("DB_HOST")
port = os.getenv("DB_PORT")
database = os.getenv("MYSQL_DATABASE")

DATABASE_URL = f"mysql+pymysql://{user}:{password}@{host}:{port}/{database}"

engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)


# -----------------------------------------------------------------------
# ÉTAPE A — Peuplement de la table BATIMENTS
# -----------------------------------------------------------------------

def inserer_batiments(df, session):
    """
    Insère tous les bâtiments uniques dans la table BATIMENTS.
    Retourne un dictionnaire { nom_batiment: batiment_id } pour résoudre les IDs ensuite.
    """
    # On récupère les couples uniques (batiment, type_batiment)
    # drop_duplicates sur le sous-ensemble de colonnes, après avoir retiré les lignes
    # où le nom du bâtiment est manquant
    batiments_df = df.dropna(subset=["batiment"]).drop_duplicates(subset="batiment")

    mapping_batiments = {}  # { "Tour Horizon": 1, "Résidence Les Tilleuls": 2, ... }

    for index, ligne in batiments_df.iterrows():
        nom = ligne["batiment"]
        type_bat = ligne["type_batiment"]

        # Vérification : le bâtiment existe-t-il déjà en base ?
        existant = session.query(Batiment).filter_by(nom=nom).first()
        if existant is not None:
            mapping_batiments[nom] = existant.batiment_id
        else:
            nouveau_batiment = Batiment(nom=nom, type_batiment=type_bat)
            session.add(nouveau_batiment)
            session.commit()
            # Après le commit, SQLAlchemy a rempli batiment_id (auto-increment)
            mapping_batiments[nom] = nouveau_batiment.batiment_id

    print(f"{len(mapping_batiments)} bâtiments chargés.")
    return mapping_batiments


# -----------------------------------------------------------------------
# ÉTAPE B — Peuplement de la table COMPTEURS
# -----------------------------------------------------------------------

def inserer_compteurs(df, session):
    """
    Insère tous les compteurs uniques dans la table COMPTEURS,
    en conservant leur source_energie.
    """
    # Couples uniques (compteur_id, source_energie)
    compteurs_df = df.dropna(subset=["compteur_id"]).drop_duplicates(subset="compteur_id")

    nb = 0
    for index, ligne in compteurs_df.iterrows():
        compteur_id = ligne["compteur_id"]
        source = ligne["source_energie"]

        existant = session.query(Compteur).filter_by(compteur_id=compteur_id).first()
        if existant is None:
            nouveau_compteur = Compteur(compteur_id=compteur_id, source_energie=source)
            session.add(nouveau_compteur)
            nb += 1

    session.commit()
    print(f"{nb} compteurs chargés.")


# -----------------------------------------------------------------------
# ÉTAPE C — Validation et insertion des RELEVES
# -----------------------------------------------------------------------

# 12.3 — Validation des colonnes obligatoires
def valider_ligne(ligne):
    """Lève une exception si une colonne obligatoire est manquante ou nulle."""
    colonnes_obligatoires = ["releve_id", "consommation_kwh", "surface_m2"]
    for col in colonnes_obligatoires:
        if pd.isna(ligne[col]):
            raise ValueError(f"Colonne obligatoire manquante ou nulle : {col}")


# 12.4 — Insertion avec gestion des doublons et des erreurs
def inserer_releves(df, session, mapping_batiments):
    """
    Insère les relevés dans RELEVES en résolvant l'ID du bâtiment
    et en incluant le jour_semaine.
    """
    nb_inseres = 0
    nb_doublons = 0
    nb_erreurs = 0

    # Liste des jours pour reconstruire jour_semaine depuis les colonnes one-hot
    jours = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]

    for index, ligne in df.iterrows():

        try:
            # Validation des colonnes obligatoires
            valider_ligne(ligne)

            # Vérification doublon sur releve_id
            existant = session.query(Releve).filter_by(
                releve_id=ligne["releve_id"]
            ).first()

            if existant is not None:
                print(f"Doublon ignoré : {ligne['releve_id']}")
                nb_doublons += 1
                continue

            # Résolution de l'ID du bâtiment depuis le dictionnaire de mapping
            batiment_id = mapping_batiments.get(ligne["batiment"])

            # Reconstruction du jour_semaine depuis les colonnes one-hot
            # (la colonne jour_semaine originale n'existe plus après get_dummies)
            jour = None
            for j in jours:
                col_name = f"jour_semaine_{j}"
                if col_name in ligne and ligne[col_name] == 1:
                    jour = j
                    break

            # Création de l'objet ORM complet
            releve = Releve(
                releve_id=ligne["releve_id"],
                batiment_id=batiment_id,
                compteur_id=ligne.get("compteur_id"),
                consommation_kwh=ligne["consommation_kwh"],
                surface_m2=ligne["surface_m2"],
                temperature_ext_c=ligne.get("temperature_ext_c"),
                heure_releve=ligne.get("heure_releve"),
                jour_semaine=jour,
            )

            session.add(releve)
            session.commit()
            nb_inseres += 1

        except ValueError as e:
            print(f"Erreur de validation ligne {index} : {e}")
            nb_erreurs += 1

        except Exception as e:
            session.rollback()
            print(f"Erreur d'insertion ligne {index} : {e}")
            nb_erreurs += 1

    print(f"\nRésumé : {nb_inseres} insérés, {nb_doublons} doublons ignorés, {nb_erreurs} erreurs")


# -----------------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------------

def main():
    df = pd.read_csv("releves_propres.csv")
    session = Session()

    # Ordre impératif : bâtiments et compteurs avant les relevés (contraintes FK)
    mapping_batiments = inserer_batiments(df, session)
    inserer_compteurs(df, session)
    inserer_releves(df, session, mapping_batiments)

    session.close()


if __name__ == "__main__":
    main()
```

> **Explication :**
>
> **Pourquoi insérer les bâtiments et les compteurs en premier ?**
> La table `RELEVES` contient des clés étrangères vers `BATIMENTS` et `COMPTEURS`. Si on essaie d'insérer un relevé qui référence un bâtiment inexistant, MySQL lève une erreur d'intégrité référentielle. L'ordre d'insertion est donc obligatoire.
>
> **Le dictionnaire `mapping_batiments`**
> On construit un dictionnaire `{ nom_batiment → batiment_id }` après avoir inséré les bâtiments. Cela permet de résoudre le nom textuel ("Tour Horizon") en identifiant numérique (1) au moment d'insérer chaque relevé, sans refaire de requête SQL coûteuse.
>
> **Pourquoi `drop_duplicates` pour les bâtiments et compteurs ?**
> Un même bâtiment ou compteur apparaît dans de nombreux relevés. On ne veut l'insérer qu'une seule fois dans sa table de référence — d'où le `drop_duplicates` qui garde une seule occurrence par entité.
>
> **Reconstruction de `jour_semaine` depuis les colonnes one-hot**
> Après le `get_dummies` de la Partie 4, la colonne `jour_semaine` a été supprimée et remplacée par des colonnes binaires (`jour_semaine_lundi`, etc.). Pour réinsérer le jour en texte dans la base, on parcourt ces colonnes et on retrouve celle qui vaut `1`.
>
> **`session.rollback()` en cas d'erreur SQLAlchemy**
> Sans rollback, la session reste dans un état d'erreur et toutes les insertions suivantes échouent aussi. Le rollback remet la session dans un état propre pour pouvoir continuer avec la ligne suivante.

---

## Partie 13 — Impact écologique

### 13.1 — Estimation via Green Algorithms

Rendez-vous sur [https://www.green-algorithms.org/](https://www.green-algorithms.org/) et renseignez :
- **Runtime** : 10 minutes
- **Cores** : 1 CPU
- **Memory** : 4 Go (valeur par défaut raisonnable)
- **Location** : France

**Résultats indicatifs (ordre de grandeur pour cet exemple) :**
| Métrique | Valeur estimée |
|---|---|
| Consommation énergétique | ~0.003 kWh |
| Émissions CO₂ | ~1.2 gCO₂eq |

> Les valeurs exactes dépendent de l'outil utilisé et de ses paramètres. Ce qui compte dans l'examen, c'est la démarche et les ordres de grandeur.

---

### 13.2 — Réduction de l'empreinte carbone (à noter dans `architecture.md`)

**Deux actions concrètes :**

1. **Choisir un datacenter en France ou en Scandinavie** : le mix énergétique français (nucléaire) et scandinave (hydraulique) produit beaucoup moins de CO₂ par kWh que le charbon. Héberger son infrastructure sur des serveurs dans ces régions réduit directement les émissions.

2. **Réduire la complexité du modèle** : un `RandomForestRegressor` avec 100 arbres (par défaut) est plus coûteux qu'une régression linéaire ou qu'un arbre unique. Comparer les performances de modèles plus simples avant d'opter pour un modèle complexe permet d'économiser de l'énergie d'entraînement et d'inférence.
