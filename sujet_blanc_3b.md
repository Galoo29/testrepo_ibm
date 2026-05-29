# Examen Blanc №2 — Bloc 3 RNCP Data Engineer
**Durée : 4 heures | Documents interdits**

---

## Contexte général

Vous êtes Data Engineer chez **TelcoChurn**, un opérateur télécom européen confronté à un taux de désabonnement (churn) en hausse. Votre équipe Data Science a développé un modèle de machine learning qui prédit la probabilité qu'un client résilie son abonnement dans les 3 prochains mois.

Votre mission : **industrialiser ce modèle** en construisant une API de prédiction (avec endpoints unitaire ET batch), en la conteneurisant, en la déployant sur Kubernetes avec une gestion propre des secrets, en mettant en place un pipeline CI/CD GitLab complet, et en monitorant le tout avec Prometheus et Grafana.

L'archive à rendre contiendra l'ensemble des fichiers produits, organisés selon la structure demandée.

---

## Structure de rendu attendue

```
telcochurn/
├── api/
│   ├── main.py
│   ├── model.py
│   ├── schemas.py
│   ├── requirements.txt
│   └── Dockerfile
├── tests/
│   ├── conftest.py
│   └── test_api.py
├── model/
│   └── train_and_save.py
├── .env.example
├── docker-compose.yml
├── .gitlab-ci.yml
├── kubernetes/
│   ├── namespace.yml
│   ├── configmap.yml
│   ├── secret.yml
│   ├── persistentvolume.yml
│   ├── persistentvolumeclaim.yml
│   ├── deployment.yml
│   └── service.yml
└── monitoring/
    ├── prometheus/
    │   └── prometheus.yml
    └── grafana/
        └── datasources/
            └── prometheus.yml
```

---

## Partie 1 — Environnement et modèle ML (20 points)

### 1.1 — Variables d'environnement : deux contextes distincts (5 points)

Vous devez configurer les variables d'environnement à **deux niveaux** différents.

**a) Niveau machine (shell)** — Pour que vos scripts Python lancés en CLI accèdent automatiquement à ces variables, ajoutez-les de manière persistante au shell Bash :

| Variable | Valeur |
|---|---|
| `TELCOCHURN_ENV` | `production` |
| `MODEL_PATH` | `/app/model/churn_model.joblib` |
| `API_PORT` | `8001` |

Quelle commande et quel fichier utilisez-vous ? Comment rendre le changement effectif sans rouvrir le terminal ?

**b) Niveau projet (Docker Compose)** — Créez un fichier `.env.example` à la racine du projet contenant les **mêmes** variables ci-dessus + une variable supplémentaire `API_KEY=changeme` qui sera utilisée par l'API pour sécuriser ses endpoints.

Expliquez **en 2-3 lignes** la différence d'usage entre `.bashrc` et `.env`, et pourquoi le fichier `.env.example` (et non `.env`) est commité dans le dépôt Git.

### 1.2 — Environnement virtuel Python (3 points)

- a) Créez un environnement virtuel nommé `venv_telco` dans le dossier `telcochurn/`.
- b) Activez-le et installez : `fastapi`, `uvicorn`, `scikit-learn`, `joblib`, `pandas`, `pytest`, `pytest-mock`, `httpx`, `prometheus-fastapi-instrumentator`, `python-dotenv`.
- c) Générez `api/requirements.txt`. Comment désactiver l'environnement virtuel ?

### 1.3 — Entraînement et sauvegarde du modèle (7 points)

Écrivez le script `model/train_and_save.py` qui :

- Charge le dataset Telco Customer Churn depuis l'URL :
  `https://raw.githubusercontent.com/IBM/telco-customer-churn-on-icp4d/master/data/Telco-Customer-Churn.csv`
- Nettoie les données :
  - Supprime la colonne `customerID`
  - Convertit `TotalCharges` en numérique (gérer les valeurs vides avec `pd.to_numeric(..., errors='coerce')` puis drop les NaN)
  - Encode la cible `Churn` (`Yes` → 1, `No` → 0)
  - Applique un `pd.get_dummies()` sur les colonnes catégorielles
- Entraîne un modèle `GradientBoostingClassifier` avec `n_estimators=150`, `max_depth=4`, `random_state=42`
- Sauvegarde **trois objets** avec `joblib` :
  - Le modèle → `model/churn_model.joblib`
  - Le scaler StandardScaler → `model/scaler.joblib`
  - La liste des noms de colonnes attendues → `model/feature_columns.joblib`
- Affiche l'accuracy ET le ROC-AUC sur le jeu de test (20%)

Le script doit lire le chemin de sauvegarde depuis la variable d'environnement `MODEL_PATH`, avec fallback sur `./model/churn_model.joblib`.

### 1.4 — Lecture d'un notebook Jupyter (5 points)

Voici un extrait de notebook fourni par votre équipe Data Science :

```python
# Cellule 1
import pandas as pd
import joblib

model = joblib.load("model/churn_model.joblib")
scaler = joblib.load("model/scaler.joblib")
feature_columns = joblib.load("model/feature_columns.joblib")

# Cellule 2
customer_raw = {
    "gender": "Female",
    "SeniorCitizen": 0,
    "tenure": 12,
    "MonthlyCharges": 85.5,
    "TotalCharges": 1020.3,
    "Contract": "Month-to-month",
    "PaymentMethod": "Electronic check"
}

customer_df = pd.DataFrame([customer_raw])
customer_encoded = pd.get_dummies(customer_df)
customer_aligned = customer_encoded.reindex(columns=feature_columns, fill_value=0)

scaled = scaler.transform(customer_aligned)
proba = model.predict_proba(scaled)[0][1]
print(f"Probabilité de churn : {proba:.2%}")
```

**Questions :**
- a) Pourquoi utilise-t-on `reindex(columns=feature_columns, fill_value=0)` après le `get_dummies()` ? Que se passerait-il sans cette étape ?
- b) Pourquoi sauvegarder `feature_columns` au moment de l'entraînement ?
- c) Si `proba` vaut `0.78`, comment interpréter ce résultat côté métier ? Quelle action déclencher ?

---

## Partie 2 — API FastAPI (25 points)

### 2.1 — Schémas Pydantic (5 points)

Créez le fichier `api/schemas.py` contenant :

- Une classe `CustomerData` héritant de `pydantic.BaseModel` avec les champs suivants :
  - `gender: str`, `SeniorCitizen: int`, `tenure: int`, `MonthlyCharges: float`, `TotalCharges: float`
  - `Contract: str`, `PaymentMethod: str`, `InternetService: str`, `PaperlessBilling: str`
- Une classe `BatchRequest` qui contient une liste `customers: list[CustomerData]`
- Une classe `PredictionResponse` avec :
  - `churn_probability: float`
  - `churn_prediction: int` (0 ou 1)
  - `retention_priority: str` (valeurs : `"low"`, `"medium"`, `"high"`, `"critical"`)
- Une classe `BatchResponse` contenant une liste `predictions: list[PredictionResponse]` et un champ `count: int`

### 2.2 — Logique métier (5 points)

Créez le fichier `api/model.py` avec une fonction `load_artifacts()` et une fonction `predict(customer: CustomerData)` qui :

- Charge le modèle, le scaler ET les `feature_columns` depuis les chemins définis par variables d'environnement
- Applique la même transformation que dans le notebook (`get_dummies` + `reindex`)
- Retourne un dictionnaire avec `churn_probability`, `churn_prediction`, et `retention_priority` calculé ainsi :
  - probabilité < 0.25 → `"low"`
  - 0.25 ≤ proba < 0.5 → `"medium"`
  - 0.5 ≤ proba < 0.75 → `"high"`
  - proba ≥ 0.75 → `"critical"`

### 2.3 — Application FastAPI (10 points)

Créez le fichier `api/main.py` avec :

- **Route** `GET /health` → retourne `{"status": "ok", "env": <TELCOCHURN_ENV>, "version": "1.0.0"}`
- **Route** `POST /predict` → accepte un body `CustomerData`, retourne une `PredictionResponse`
- **Route** `POST /predict/batch` → accepte un body `BatchRequest`, retourne une `BatchResponse`. Doit refuser un batch de plus de 1000 clients (retourner un code 413 dans ce cas).
- **Route** `GET /metrics` exposée par `prometheus-fastapi-instrumentator`
- L'instrumentation Prometheus doit ajouter un label `app_name="telcochurn-api"` à toutes les métriques
- Le chargement du modèle doit se faire au démarrage via `@app.on_event("startup")`
- Les routes `/predict` et `/predict/batch` doivent vérifier la présence d'un header `X-API-Key` correspondant à la variable d'environnement `API_KEY`. Si absent ou incorrect, retourner un code 401.

### 2.4 — Requêtes curl (5 points)

Écrivez les commandes `curl` permettant de :

- a) Tester la route `/health`
- b) Envoyer une prédiction unitaire (avec le header API Key) pour un client `Female`, `tenure=2`, `MonthlyCharges=99.65`, `TotalCharges=199.30`, `Contract=Month-to-month`, `PaymentMethod=Electronic check`, `InternetService=Fiber optic`, `PaperlessBilling=Yes`, `SeniorCitizen=0`
- c) Envoyer un batch de 2 clients sur `/predict/batch`
- d) Vérifier que la route refuse une requête sans header `X-API-Key` (avec affichage du code HTTP retourné)

---

## Partie 3 — Tests avec Pytest (10 points)

### 3.1 — Fixtures et tests (10 points)

Créez `tests/conftest.py` et `tests/test_api.py` avec :

**Dans `conftest.py`** :
- Une fixture `client` (scope `module`) qui retourne un `TestClient` de FastAPI
- Une fixture `valid_customer` (scope `function`) qui retourne un dictionnaire client valide
- Une fixture `api_headers` qui retourne les headers HTTP avec la bonne API Key

**Dans `test_api.py`** : au minimum 5 tests utilisant ces fixtures :
- `test_health_ok` : code 200, champ `status == "ok"`, champ `version` présent
- `test_predict_requires_api_key` : sans header → 401
- `test_predict_valid_input` : avec header et données valides → 200, structure complète
- `test_batch_predict_too_large` : un batch de 1001 clients → code 413
- `test_predict_invalid_input` paramétré avec `@pytest.mark.parametrize` sur **3 cas invalides** : body vide, type incorrect (string au lieu de float), champ obligatoire manquant → tous doivent retourner 422

---

## Partie 4 — Docker (20 points)

### 4.1 — Dockerfile (8 points)

Créez `api/Dockerfile` :

- Image de base : `python:3.11-slim`
- Crée et utilise un **utilisateur non-root** nommé `appuser` (sécurité)
- Répertoire de travail : `/app`
- Copie `requirements.txt` **avant** le reste pour optimiser le cache Docker
- Installe les dépendances avec `--no-cache-dir`
- Copie le code source
- Définit les variables d'environnement par défaut
- Ajoute un `HEALTHCHECK` qui appelle `/health` toutes les 30 secondes
- Expose le port 8001
- Lance `uvicorn`

### 4.2 — Docker Compose (12 points)

Créez `docker-compose.yml` à la racine avec **3 services** :

**Service `api`** :
- Build depuis `./api`
- Image taguée : `telcochurn-api:1.0.0`
- Port : `8001:8001`
- Volumes : `./model:/app/model` (en lecture seule via `:ro`)
- Variables injectées depuis `.env`
- `restart: unless-stopped`

**Service `prometheus`** :
- Image : `prom/prometheus:v2.51.0` (version fixée pour la reproductibilité)
- Port : `9090:9090`
- Volume : `./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml`
- Dépend de `api` avec `condition: service_healthy` (nécessite le healthcheck du Dockerfile)

**Service `grafana`** :
- Image : `grafana/grafana:10.4.0`
- Port : `3000:3000`
- Volumes :
  - `./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources`
  - Un **volume nommé** `grafana-data:/var/lib/grafana` (pour persister les dashboards)
- Variables d'environnement : `GF_SECURITY_ADMIN_USER=admin`, `GF_SECURITY_ADMIN_PASSWORD` lue depuis `.env`
- Dépend de `prometheus`

Tous les services doivent partager un réseau dédié `telco-net`.

---

## Partie 5 — GitLab CI/CD (15 points)

### 5.1 — Pipeline GitLab (15 points)

Créez le fichier `.gitlab-ci.yml` avec **4 stages** : `lint`, `test`, `build`, `deploy`.

Définissez également une **section `variables` globale** déclarant `PYTHON_VERSION: "3.11"`.

**Stage `lint`** — job `lint_python` :
- Image : `python:$PYTHON_VERSION-slim`
- Installe `flake8`
- Lance `flake8 api/ tests/ --max-line-length=120`
- S'exécute sur toutes les branches

**Stage `test`** — job `run_tests` :
- Image : `python:$PYTHON_VERSION-slim`
- Configure un **cache** sur le dossier `.pip-cache/` pour accélérer les builds
- Installe les dépendances
- Lance `pytest tests/ --verbose --junitxml=report.xml`
- Déclare `report.xml` en tant qu'**artifact** (avec `reports.junit` pour intégration GitLab)
- Dépend du stage `lint`

**Stage `build`** — job `build_image` :
- Image : `docker:24`
- Service : `docker:24-dind`
- Login Docker Hub avec `$DOCKER_HUB_USER` et `$DOCKER_HUB_TOKEN`
- Construit l'image et la tag avec **deux tags** : `$CI_COMMIT_SHORT_SHA` ET `latest`
- Pousse les deux tags
- Ne s'exécute que sur la branche `main`

**Stage `deploy`** — job `deploy_k8s` :
- Image : `bitnami/kubectl:latest`
- Applique tous les manifests du dossier `kubernetes/` avec `kubectl apply -f`
- Utilise la variable CI `$KUBECONFIG`
- Lance ensuite `kubectl rollout status deployment/telcochurn-deployment -n telcochurn` pour valider le déploiement
- Ne s'exécute que sur `main`, et **uniquement en mode manuel** (`when: manual`)

Expliquez également comment enregistrer un runner GitLab de type `shell` sur votre machine virtuelle.

---

## Partie 6 — Kubernetes (20 points)

Créez les 7 manifests dans `kubernetes/`.

### 6.1 — Namespace (2 points)
`namespace.yml` : namespace `telcochurn` avec un label `environment: production`.

### 6.2 — ConfigMap (3 points)
`configmap.yml` dans le namespace `telcochurn`, nommé `telcochurn-config` :
- `TELCOCHURN_ENV=production`
- `API_PORT=8001`
- `MODEL_PATH=/app/model/churn_model.joblib`

### 6.3 — Secret (3 points)
`secret.yml` dans le namespace `telcochurn`, nommé `telcochurn-secret`, contenant la clé `API_KEY` (valeur encodée en base64).

Indiquez la commande qui permet de générer la valeur base64 à partir d'une chaîne en clair.

### 6.4 — PersistentVolume et PersistentVolumeClaim (4 points)
- `persistentvolume.yml` : PV nommé `telco-model-pv`, capacité `500Mi`, `accessMode: ReadOnlyMany`, `hostPath: /data/telco`
- `persistentvolumeclaim.yml` : PVC nommé `telco-model-pvc` dans le namespace `telcochurn`, demandant `500Mi` en `ReadOnlyMany`

### 6.5 — Deployment (5 points)
`deployment.yml` dans le namespace `telcochurn` :
- Nom : `telcochurn-deployment`
- `replicas: 3`
- Image : `<votre_dockerhub_user>/telcochurn-api:1.0.0`
- Port conteneur : `8001`
- Variables d'environnement **non sensibles** depuis le ConfigMap, et `API_KEY` depuis le Secret
- Volume monté en lecture seule depuis le PVC sur `/app/model`
- `readinessProbe` ET `livenessProbe` sur `GET /health`, port `8001`
- `resources.limits`: `cpu: 500m`, `memory: 512Mi`
- `resources.requests`: `cpu: 200m`, `memory: 256Mi`

### 6.6 — Service (3 points)
`service.yml` dans le namespace `telcochurn` :
- Nom : `telcochurn-service`
- Type : `NodePort`
- Port `8001` mappé sur `nodePort: 30081`

---

## Partie 7 — Monitoring : Prometheus & Grafana (10 points)

### 7.1 — Configuration Prometheus (3 points)

`monitoring/prometheus/prometheus.yml` :
- `global.scrape_interval: 15s`
- `global.evaluation_interval: 30s`
- Un job `telcochurn-api` qui scrape `api:8001/metrics` toutes les `10s`
- Un job `prometheus-self` qui scrape Prometheus lui-même sur `localhost:9090`

### 7.2 — Datasource Grafana (2 points)

`monitoring/grafana/datasources/prometheus.yml` configurant Prometheus comme source par défaut (URL : `http://prometheus:9090`).

### 7.3 — PromQL (5 points)

Écrivez les requêtes PromQL pour :

- a) Le **nombre total de prédictions** servies sur la route `/predict` (unitaire)
- b) Le **taux de requêtes par seconde** sur `/predict/batch` sur les 5 dernières minutes
- c) Le **ratio d'erreurs** (5xx) sur l'ensemble de l'API sur 1 minute, exprimé en pourcentage
- d) Le **99e percentile de latence** des requêtes `/predict/batch` sur 10 minutes
- e) Le **nombre de requêtes refusées (401)** par minute, segmenté par route (`handler`)

---

## Barème récapitulatif

| Partie | Thème | Points |
|---|---|---|
| 1 | Environnement, variables, modèle ML | 20 |
| 2 | API FastAPI | 25 |
| 3 | Tests Pytest | 10 |
| 4 | Docker & Docker Compose | 20 |
| 5 | GitLab CI/CD | 15 |
| 6 | Kubernetes | 20 |
| 7 | Prometheus & Grafana | 10 |
| **Total** | | **120** |

---

*Bonne chance ! Pensez à valider chaque composant indépendamment avant l'intégration finale (API en local, puis Docker Compose, puis Kubernetes).*
