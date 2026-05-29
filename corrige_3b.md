# Corrigé — Examen Blanc №2 Bloc 3 RNCP Data Engineer

---

## Partie 1 — Environnement et modèle ML

### 1.1 — Variables d'environnement : deux contextes distincts

**a) Niveau machine (shell) — `.bashrc`**

```bash
# Ajouter à la fin de ~/.bashrc
echo 'export TELCOCHURN_ENV=production' >> ~/.bashrc
echo 'export MODEL_PATH=/app/model/churn_model.joblib' >> ~/.bashrc
echo 'export API_PORT=8001' >> ~/.bashrc

# Rendre effectif sans rouvrir le terminal
source ~/.bashrc
```

**b) Niveau projet — `.env.example`**

```bash
# .env.example — à committer dans Git, sert de template
TELCOCHURN_ENV=production
MODEL_PATH=/app/model/churn_model.joblib
API_PORT=8001
API_KEY=changeme
```

**Différence d'usage `.bashrc` vs `.env` :**

`.bashrc` configure ton shell utilisateur sur ta machine : les variables sont disponibles dans tous tes terminaux, indépendamment du projet. `.env` est un fichier de configuration **propre à un projet**, lu par des outils spécifiques (Docker Compose, `python-dotenv`) au moment où ils en ont besoin. Le fichier `.env.example` est commité dans Git pour documenter quelles variables le projet attend, **sans révéler les vraies valeurs**. Le `.env` réel (avec les secrets) est ajouté au `.gitignore` pour ne jamais quitter la machine du développeur.

---

### 1.2 — Environnement virtuel Python

```bash
# a) Création
cd telcochurn/
python3 -m venv venv_telco

# b) Activation + installation
source venv_telco/bin/activate
pip install fastapi uvicorn scikit-learn joblib pandas pytest pytest-mock httpx prometheus-fastapi-instrumentator python-dotenv

# c) Génération du requirements.txt
pip freeze > api/requirements.txt

# Désactivation
deactivate
```

> **Pourquoi `pytest-mock` ?** Cette extension fournit la fixture `mocker` qui simplifie l'écriture de mocks dans les tests — utile pour simuler le chargement du modèle sans le charger réellement.

---

### 1.3 — Entraînement et sauvegarde du modèle

**Fichier `model/train_and_save.py`** :

```python
import os
import pandas as pd
import joblib
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, roc_auc_score

MODEL_PATH = os.getenv("MODEL_PATH", "./model/churn_model.joblib")
SCALER_PATH = os.getenv("SCALER_PATH", "./model/scaler.joblib")
FEATURES_PATH = os.getenv("FEATURES_PATH", "./model/feature_columns.joblib")

# Chargement du dataset
url = "https://raw.githubusercontent.com/IBM/telco-customer-churn-on-icp4d/master/data/Telco-Customer-Churn.csv"
df = pd.read_csv(url)

# Nettoyage
df = df.drop("customerID", axis=1)
df["TotalCharges"] = pd.to_numeric(df["TotalCharges"], errors="coerce")
df = df.dropna()
df["Churn"] = df["Churn"].map({"Yes": 1, "No": 0})

# Séparation X/y
y = df["Churn"]
X = df.drop("Churn", axis=1)
X = pd.get_dummies(X)

# Sauvegarde des noms de colonnes APRÈS encoding (essentiel pour l'inférence)
feature_columns = X.columns.tolist()

# Split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

# Normalisation
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# Entraînement
model = GradientBoostingClassifier(n_estimators=150, max_depth=4, random_state=42)
model.fit(X_train_scaled, y_train)

# Évaluation
y_pred = model.predict(X_test_scaled)
y_proba = model.predict_proba(X_test_scaled)[:, 1]
print(f"Accuracy : {accuracy_score(y_test, y_pred):.2%}")
print(f"ROC-AUC  : {roc_auc_score(y_test, y_proba):.4f}")

# Sauvegarde
os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
joblib.dump(model, MODEL_PATH)
joblib.dump(scaler, SCALER_PATH)
joblib.dump(feature_columns, FEATURES_PATH)
print(f"Modèle, scaler et feature columns sauvegardés.")
```

> **Pourquoi `stratify=y` ?** Le dataset Telco est déséquilibré (~27% de churn). `stratify` garantit que la proportion churn/non-churn est identique dans le train et le test, ce qui rend l'évaluation plus fiable.

> **Pourquoi ROC-AUC en plus de l'accuracy ?** Sur un dataset déséquilibré, l'accuracy peut être trompeuse (un modèle qui prédit toujours "non-churn" obtiendrait 73% d'accuracy). Le ROC-AUC mesure la capacité du modèle à discriminer les deux classes indépendamment du seuil.

> **Sauvegarde des `feature_columns`** : après `pd.get_dummies()`, le nombre et l'ordre des colonnes dépendent des valeurs présentes dans le dataset d'entraînement. Il est impératif de sauvegarder cette liste pour pouvoir aligner les données d'inférence sur la même structure.

---

### 1.4 — Lecture du notebook

**a) Rôle du `reindex(columns=feature_columns, fill_value=0)`**

Quand on appelle `pd.get_dummies(customer_df)` sur un seul client, le résultat contient uniquement les colonnes correspondant aux valeurs catégorielles présentes dans **ce client**. Par exemple, si le client a `Contract="Month-to-month"`, on aura une colonne `Contract_Month-to-month` mais pas `Contract_Two year`.

`reindex` aligne ce DataFrame sur la liste exacte des colonnes attendues par le modèle : il ajoute les colonnes manquantes (remplies avec `0`) et supprime celles en trop. **Sans cette étape**, on aurait soit une erreur "shape mismatch" lors du `scaler.transform()`, soit pire — des prédictions silencieusement erronées si les colonnes ne sont pas dans le même ordre.

**b) Pourquoi sauvegarder `feature_columns` ?**

C'est le **contrat** entre l'entraînement et l'inférence. Le modèle a appris à associer une feature à une position précise dans le vecteur d'entrée. À l'inférence, il faut garantir cette même structure : mêmes colonnes, même ordre. Sauvegarder la liste au moment de l'entraînement (et la versionner avec le modèle) est la seule façon de garantir cette cohérence.

**c) Interprétation de `proba = 0.78`**

Le modèle estime à **78% la probabilité** que ce client résilie son abonnement dans les 3 prochains mois. C'est une probabilité élevée → le client doit être classé en priorité de rétention **`critical`** (≥ 0.75). Côté métier, cela déclencherait typiquement une action proactive : appel d'un conseiller commercial, offre promotionnelle ciblée, ou geste commercial sur la prochaine facture.

---

## Partie 2 — API FastAPI

### 2.1 — Schémas Pydantic

**Fichier `api/schemas.py`** :

```python
from pydantic import BaseModel
from typing import List

class CustomerData(BaseModel):
    gender: str
    SeniorCitizen: int
    tenure: int
    MonthlyCharges: float
    TotalCharges: float
    Contract: str
    PaymentMethod: str
    InternetService: str
    PaperlessBilling: str

class BatchRequest(BaseModel):
    customers: List[CustomerData]

class PredictionResponse(BaseModel):
    churn_probability: float
    churn_prediction: int
    retention_priority: str

class BatchResponse(BaseModel):
    predictions: List[PredictionResponse]
    count: int
```

> **Pourquoi séparer `BatchRequest` et une simple `List[CustomerData]` ?** Encapsuler la liste dans un objet permet d'ajouter facilement d'autres champs au batch plus tard (ex: `request_id`, `priority_flag`) sans casser l'API. C'est une bonne pratique d'évolutivité.

---

### 2.2 — Logique métier

**Fichier `api/model.py`** :

```python
import os
import joblib
import pandas as pd
from api.schemas import CustomerData

MODEL_PATH = os.getenv("MODEL_PATH", "./model/churn_model.joblib")
SCALER_PATH = os.getenv("SCALER_PATH", "./model/scaler.joblib")
FEATURES_PATH = os.getenv("FEATURES_PATH", "./model/feature_columns.joblib")

_model = None
_scaler = None
_feature_columns = None

def load_artifacts():
    global _model, _scaler, _feature_columns
    _model = joblib.load(MODEL_PATH)
    _scaler = joblib.load(SCALER_PATH)
    _feature_columns = joblib.load(FEATURES_PATH)

def _compute_priority(proba: float) -> str:
    if proba < 0.25:
        return "low"
    elif proba < 0.5:
        return "medium"
    elif proba < 0.75:
        return "high"
    else:
        return "critical"

def predict(customer: CustomerData) -> dict:
    # Conversion vers DataFrame
    df = pd.DataFrame([customer.dict()])
    # Encoding identique à l'entraînement
    encoded = pd.get_dummies(df)
    # Alignement avec les feature columns du modèle
    aligned = encoded.reindex(columns=_feature_columns, fill_value=0)
    # Normalisation et prédiction
    scaled = _scaler.transform(aligned)
    proba = float(_model.predict_proba(scaled)[0][1])
    prediction = int(proba >= 0.5)

    return {
        "churn_probability": proba,
        "churn_prediction": prediction,
        "retention_priority": _compute_priority(proba)
    }
```

> **Pourquoi `int(proba >= 0.5)` au lieu de `_model.predict()` ?** Le résultat est identique (par défaut sklearn utilise un seuil à 0.5), mais ça nous évite un second appel au modèle et garde le code lisible. Plus tard, si on veut ajuster le seuil pour des raisons métier (ex: privilégier le rappel), il suffit de modifier cette ligne.

---

### 2.3 — Application FastAPI

**Fichier `api/main.py`** :

```python
import os
import uvicorn
from fastapi import FastAPI, Header, HTTPException
from prometheus_fastapi_instrumentator import Instrumentator
from api.schemas import CustomerData, BatchRequest, PredictionResponse, BatchResponse
from api.model import load_artifacts, predict as ml_predict

app = FastAPI(title="TelcoChurn API", version="1.0.0")

API_KEY = os.getenv("API_KEY", "changeme")
MAX_BATCH_SIZE = 1000

# Instrumentation Prometheus avec label custom
instrumentator = Instrumentator().instrument(
    app,
    metric_namespace="telcochurn",
)

@app.on_event("startup")
async def startup_event():
    load_artifacts()
    instrumentator.expose(app)

def verify_api_key(x_api_key: str = Header(None, alias="X-API-Key")):
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")

@app.get("/health")
def health():
    return {
        "status": "ok",
        "env": os.getenv("TELCOCHURN_ENV", "unknown"),
        "version": "1.0.0"
    }

@app.post("/predict", response_model=PredictionResponse)
def predict_one(customer: CustomerData, x_api_key: str = Header(None, alias="X-API-Key")):
    verify_api_key(x_api_key)
    result = ml_predict(customer)
    return PredictionResponse(**result)

@app.post("/predict/batch", response_model=BatchResponse)
def predict_batch(batch: BatchRequest, x_api_key: str = Header(None, alias="X-API-Key")):
    verify_api_key(x_api_key)
    if len(batch.customers) > MAX_BATCH_SIZE:
        raise HTTPException(
            status_code=413,
            detail=f"Batch size {len(batch.customers)} exceeds maximum of {MAX_BATCH_SIZE}"
        )
    predictions = [PredictionResponse(**ml_predict(c)) for c in batch.customers]
    return BatchResponse(predictions=predictions, count=len(predictions))

if __name__ == "__main__":
    port = int(os.getenv("API_PORT", 8001))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
```

> **Pourquoi vérifier l'API Key dans chaque route et pas en middleware ?** Pour la simplicité dans le contexte d'examen. En production, on utiliserait un middleware FastAPI ou une dépendance `Security` qui s'applique globalement, ou plus robustement OAuth2/JWT.

> **Pourquoi code 413 et pas 400 pour un batch trop gros ?** Le code 413 (`Payload Too Large`) est sémantiquement le bon code HTTP pour signaler que le corps de la requête dépasse la limite acceptée. C'est plus précis qu'un 400 générique.

> **Pourquoi `metric_namespace="telcochurn"` ?** Toutes les métriques exposées seront préfixées par `telcochurn_`, ce qui évite les collisions avec d'autres applications scrapées par le même Prometheus.

---

### 2.4 — Requêtes curl

**a) Test de `/health`**

```bash
curl -X GET http://localhost:8001/health
```

**b) Prédiction unitaire**

```bash
curl -X POST http://localhost:8001/predict \
  -H "Content-Type: application/json" \
  -H "X-API-Key: changeme" \
  -d '{
    "gender": "Female",
    "SeniorCitizen": 0,
    "tenure": 2,
    "MonthlyCharges": 99.65,
    "TotalCharges": 199.30,
    "Contract": "Month-to-month",
    "PaymentMethod": "Electronic check",
    "InternetService": "Fiber optic",
    "PaperlessBilling": "Yes"
  }'
```

**c) Batch de 2 clients**

```bash
curl -X POST http://localhost:8001/predict/batch \
  -H "Content-Type: application/json" \
  -H "X-API-Key: changeme" \
  -d '{
    "customers": [
      {
        "gender": "Female", "SeniorCitizen": 0, "tenure": 2,
        "MonthlyCharges": 99.65, "TotalCharges": 199.30,
        "Contract": "Month-to-month", "PaymentMethod": "Electronic check",
        "InternetService": "Fiber optic", "PaperlessBilling": "Yes"
      },
      {
        "gender": "Male", "SeniorCitizen": 1, "tenure": 48,
        "MonthlyCharges": 75.00, "TotalCharges": 3600.00,
        "Contract": "Two year", "PaymentMethod": "Bank transfer (automatic)",
        "InternetService": "DSL", "PaperlessBilling": "No"
      }
    ]
  }'
```

**d) Vérifier le refus sans API Key**

```bash
# L'option -i affiche les headers de réponse (dont le code HTTP)
curl -i -X POST http://localhost:8001/predict \
  -H "Content-Type: application/json" \
  -d '{"gender": "Female", "SeniorCitizen": 0, "tenure": 2, "MonthlyCharges": 99.65, "TotalCharges": 199.30, "Contract": "Month-to-month", "PaymentMethod": "Electronic check", "InternetService": "Fiber optic", "PaperlessBilling": "Yes"}'

# Alternative : -w "%{http_code}\n" pour n'afficher que le code HTTP
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8001/predict \
  -H "Content-Type: application/json" \
  -d '{...}'
# → doit afficher 401
```

> **Flags curl utilisés** : `-i` (include headers), `-s` (silent), `-o /dev/null` (discard output body), `-w "%{http_code}\n"` (write only HTTP code).

---

## Partie 3 — Tests avec Pytest

**Fichier `tests/conftest.py`** :

```python
import os
import pytest
from fastapi.testclient import TestClient

# S'assurer que l'API_KEY est définie avant de charger l'app
os.environ["API_KEY"] = "test-key-12345"

from api.main import app

@pytest.fixture(scope="module")
def client():
    return TestClient(app)

@pytest.fixture
def valid_customer():
    return {
        "gender": "Female",
        "SeniorCitizen": 0,
        "tenure": 2,
        "MonthlyCharges": 99.65,
        "TotalCharges": 199.30,
        "Contract": "Month-to-month",
        "PaymentMethod": "Electronic check",
        "InternetService": "Fiber optic",
        "PaperlessBilling": "Yes"
    }

@pytest.fixture
def api_headers():
    return {"X-API-Key": "test-key-12345"}
```

**Fichier `tests/test_api.py`** :

```python
import pytest

def test_health_ok(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "version" in data

def test_predict_requires_api_key(client, valid_customer):
    response = client.post("/predict", json=valid_customer)
    assert response.status_code == 401

def test_predict_valid_input(client, valid_customer, api_headers):
    response = client.post("/predict", json=valid_customer, headers=api_headers)
    assert response.status_code == 200
    data = response.json()
    assert "churn_probability" in data
    assert "churn_prediction" in data
    assert "retention_priority" in data
    assert data["retention_priority"] in ["low", "medium", "high", "critical"]

def test_batch_predict_too_large(client, valid_customer, api_headers):
    batch = {"customers": [valid_customer] * 1001}
    response = client.post("/predict/batch", json=batch, headers=api_headers)
    assert response.status_code == 413

@pytest.mark.parametrize("invalid_payload", [
    {},                                                          # body vide
    {"gender": "Female", "tenure": "not_a_number"},              # type incorrect
    {"gender": "Female"},                                         # champs manquants
])
def test_predict_invalid_input(client, api_headers, invalid_payload):
    response = client.post("/predict", json=invalid_payload, headers=api_headers)
    assert response.status_code == 422
```

**Commande d'exécution :**

```bash
pytest tests/ --verbose
```

> **Pourquoi `scope="module"` pour `client` ?** Le `TestClient` charge l'application FastAPI (et donc le modèle joblib) au premier appel. En limitant le scope à `module`, on évite de recharger le modèle entre chaque test, ce qui accélère significativement la suite de tests.

> **Pourquoi `@pytest.mark.parametrize` ?** Ce décorateur permet d'exécuter la même logique de test sur plusieurs jeux de données. C'est plus lisible et plus DRY que d'écrire 3 fonctions séparées. Pytest affichera chaque cas comme un test distinct dans le rapport.

> **Pourquoi définir `API_KEY` dans `conftest.py` AVANT l'import de `app` ?** Si on charge `app` avant de définir la variable d'env, `app.py` lira l'API_KEY par défaut (`"changeme"`) au moment de l'import. L'ordre est crucial.

---

## Partie 4 — Docker

### 4.1 — Dockerfile

**Fichier `api/Dockerfile`** :

```dockerfile
FROM python:3.11-slim

# Création d'un utilisateur non-root pour la sécurité
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Installation des dépendances système nécessaires à scikit-learn
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copie des dépendances EN PREMIER pour optimiser le cache Docker
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copie du code source
COPY . .

# Changement de propriétaire et bascule vers l'utilisateur non-root
RUN chown -R appuser:appuser /app
USER appuser

# Variables d'environnement par défaut
ENV TELCOCHURN_ENV=production \
    MODEL_PATH=/app/model/churn_model.joblib \
    SCALER_PATH=/app/model/scaler.joblib \
    FEATURES_PATH=/app/model/feature_columns.joblib \
    API_PORT=8001

# Healthcheck Docker
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8001/health || exit 1

EXPOSE 8001

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
```

> **Pourquoi un utilisateur non-root ?** Par défaut, les conteneurs Docker tournent en `root`. Si un attaquant compromet l'application, il a les droits root **dans le conteneur**, ce qui ouvre la porte à des escalades de privilèges (notamment via le partage de volumes). Tourner en `appuser` limite cette surface d'attaque. C'est un best practice de sécurité **exigée** dans la plupart des audits.

> **Pourquoi `--no-install-recommends` ?** apt-get installe par défaut des packages "recommandés" en plus du package demandé. `--no-install-recommends` réduit la taille de l'image et limite les vulnérabilités potentielles.

> **Pourquoi `HEALTHCHECK` ?** Permet à Docker (et Docker Compose avec `condition: service_healthy`) de savoir si le conteneur est réellement opérationnel, pas juste "running". L'option `--start-period=10s` laisse 10 secondes de grâce au démarrage (chargement du modèle) avant de commencer à compter les échecs.

---

### 4.2 — Docker Compose

**Fichier `docker-compose.yml`** :

```yaml
version: "3.9"

services:
  api:
    build:
      context: ./api
    image: telcochurn-api:1.0.0
    ports:
      - "8001:8001"
    volumes:
      - ./model:/app/model:ro
    env_file:
      - .env
    restart: unless-stopped
    networks:
      - telco-net

  prometheus:
    image: prom/prometheus:v2.51.0
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    depends_on:
      api:
        condition: service_healthy
    networks:
      - telco-net

  grafana:
    image: grafana/grafana:10.4.0
    ports:
      - "3000:3000"
    volumes:
      - ./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources
      - grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
    depends_on:
      - prometheus
    networks:
      - telco-net

volumes:
  grafana-data:

networks:
  telco-net:
    driver: bridge
```

> **Volume `:ro` (read-only)** : L'API n'a aucune raison de modifier le modèle à l'exécution. Monter le volume en lecture seule empêche toute écriture accidentelle ou malveillante, et permet aussi à plusieurs conteneurs de partager le même volume sans risque.

> **Image versionnée vs `:latest`** : `prom/prometheus:v2.51.0` est reproductible — n'importe qui qui clone le repo aura exactement la même version. `:latest` est un tag mobile qui peut introduire des breaking changes silencieux. Pour la production, **toujours fixer les versions**.

> **Volume nommé `grafana-data`** : Sans ce volume, les dashboards créés dans Grafana seraient perdus au redémarrage du conteneur. Les volumes nommés sont gérés par Docker (situés dans `/var/lib/docker/volumes/`) et persistent indépendamment du cycle de vie des conteneurs.

> **`service_healthy` vs `service_started`** : `service_started` vérifie juste que le conteneur a démarré, mais l'application peut encore être en cours d'initialisation. `service_healthy` attend que le `HEALTHCHECK` du Dockerfile passe au vert — c'est plus robuste. Nécessite que le service amont définisse un healthcheck.

---

## Partie 5 — GitLab CI/CD

**Fichier `.gitlab-ci.yml`** :

```yaml
variables:
  PYTHON_VERSION: "3.11"

stages:
  - lint
  - test
  - build
  - deploy

# Cache partagé entre les jobs Python
.python_cache: &python_cache
  cache:
    key: "$CI_COMMIT_REF_SLUG-pip"
    paths:
      - .pip-cache/

lint_python:
  stage: lint
  image: python:$PYTHON_VERSION-slim
  script:
    - pip install flake8
    - flake8 api/ tests/ --max-line-length=120

run_tests:
  stage: test
  image: python:$PYTHON_VERSION-slim
  <<: *python_cache
  variables:
    PIP_CACHE_DIR: "$CI_PROJECT_DIR/.pip-cache"
  script:
    - pip install -r api/requirements.txt
    - pytest tests/ --verbose --junitxml=report.xml
  artifacts:
    when: always
    paths:
      - report.xml
    reports:
      junit: report.xml
  needs:
    - lint_python

build_image:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
  script:
    - docker login -u $DOCKER_HUB_USER -p $DOCKER_HUB_TOKEN
    - docker build -t $DOCKER_HUB_USER/telcochurn-api:$CI_COMMIT_SHORT_SHA -t $DOCKER_HUB_USER/telcochurn-api:latest ./api
    - docker push $DOCKER_HUB_USER/telcochurn-api:$CI_COMMIT_SHORT_SHA
    - docker push $DOCKER_HUB_USER/telcochurn-api:latest
  needs:
    - run_tests
  only:
    - main

deploy_k8s:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl apply -f kubernetes/
    - kubectl rollout status deployment/telcochurn-deployment -n telcochurn
  variables:
    KUBECONFIG: $KUBECONFIG
  needs:
    - build_image
  only:
    - main
  when: manual
```

**Enregistrement d'un runner shell :**

```bash
sudo gitlab-runner register \
  --url https://gitlab.com/ \
  --registration-token <VOTRE_TOKEN> \
  --executor shell \
  --description "telco-shell-runner" \
  --tag-list "shell,linux" \
  --non-interactive
```

> **Pourquoi un cache pip ?** Sans cache, chaque job du pipeline réinstalle toutes les dépendances depuis PyPI (~30s à 1 minute). Le cache stocke les wheels téléchargés dans `.pip-cache/` et les réutilise au job suivant — gain de temps important sur les pipelines fréquents.

> **Pourquoi `key: "$CI_COMMIT_REF_SLUG-pip"` ?** La clé inclut le nom de la branche, donc chaque branche a son propre cache. Évite les conflits si deux branches ont des dépendances différentes.

> **`reports: junit: report.xml`** : intégration native GitLab — les résultats des tests apparaissent directement dans l'interface du merge request, avec mise en évidence des tests échoués. Très utile pour les revues de code.

> **Double tag (`:SHA` + `:latest`)** : Le tag SHA permet de retrouver exactement quelle version est déployée (traçabilité). Le tag `latest` est utilisé par convention pour pointer vers la dernière build stable.

> **`when: manual` sur le deploy** : Le déploiement en production ne doit jamais être automatique. `when: manual` ajoute un bouton "play" dans GitLab que seul un utilisateur autorisé peut déclencher. Bonne pratique de sécurité opérationnelle.

> **`kubectl rollout status`** : Cette commande bloque le job jusqu'à ce que le déploiement soit complètement appliqué (tous les pods de la nouvelle version sont healthy). Si un pod crash-loop, le job échoue — ce qui rend visible un mauvais déploiement immédiatement.

---

## Partie 6 — Kubernetes

### 6.1 — Namespace

**Fichier `kubernetes/namespace.yml`** :

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: telcochurn
  labels:
    environment: production
```

---

### 6.2 — ConfigMap

**Fichier `kubernetes/configmap.yml`** :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: telcochurn-config
  namespace: telcochurn
data:
  TELCOCHURN_ENV: "production"
  API_PORT: "8001"
  MODEL_PATH: "/app/model/churn_model.joblib"
```

---

### 6.3 — Secret

**Génération de la valeur base64 :**

```bash
echo -n "ma-cle-api-secrete" | base64
# → bWEtY2xlLWFwaS1zZWNyZXRl
```

> **Pourquoi `-n` ?** Sans cette option, `echo` ajoute un caractère newline `\n` à la fin, qui serait encodé aussi et corromprait le secret. `-n` supprime ce newline.

**Fichier `kubernetes/secret.yml`** :

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: telcochurn-secret
  namespace: telcochurn
type: Opaque
data:
  API_KEY: bWEtY2xlLWFwaS1zZWNyZXRl
```

> **`Secret` vs `ConfigMap` — point important** : Le base64 N'EST PAS du chiffrement, juste un encodage. N'importe qui ayant accès à l'API Kubernetes peut le décoder. La vraie protection vient des **RBAC** (Role-Based Access Control) qui restreignent l'accès aux Secrets à certains utilisateurs/services seulement. Pour un chiffrement réel au repos, il faut configurer le chiffrement etcd au niveau du cluster, ou utiliser un outil comme Sealed Secrets, Vault, ou AWS Secrets Manager.

---

### 6.4 — PersistentVolume et PersistentVolumeClaim

**Fichier `kubernetes/persistentvolume.yml`** :

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: telco-model-pv
spec:
  capacity:
    storage: 500Mi
  accessModes:
    - ReadOnlyMany
  hostPath:
    path: /data/telco
```

**Fichier `kubernetes/persistentvolumeclaim.yml`** :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: telco-model-pvc
  namespace: telcochurn
spec:
  accessModes:
    - ReadOnlyMany
  resources:
    requests:
      storage: 500Mi
```

> **Pourquoi `ReadOnlyMany` plutôt que `ReadWriteOnce` ?** Avec 3 replicas du Deployment, plusieurs pods doivent lire le modèle simultanément, potentiellement sur des nœuds différents. `ReadWriteOnce` (RWO) ne permet qu'un seul nœud à monter le volume — incompatible avec 3 replicas multi-nœuds. `ReadOnlyMany` (ROX) permet la lecture parallèle, et le modèle n'a jamais besoin d'être modifié à l'exécution.

---

### 6.5 — Deployment

**Fichier `kubernetes/deployment.yml`** :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: telcochurn-deployment
  namespace: telcochurn
spec:
  replicas: 3
  selector:
    matchLabels:
      app: telcochurn
  template:
    metadata:
      labels:
        app: telcochurn
    spec:
      containers:
        - name: telcochurn-api
          image: <votre_dockerhub_user>/telcochurn-api:1.0.0
          ports:
            - containerPort: 8001
          envFrom:
            - configMapRef:
                name: telcochurn-config
          env:
            - name: API_KEY
              valueFrom:
                secretKeyRef:
                  name: telcochurn-secret
                  key: API_KEY
          volumeMounts:
            - name: model-storage
              mountPath: /app/model
              readOnly: true
          readinessProbe:
            httpGet:
              path: /health
              port: 8001
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8001
            initialDelaySeconds: 30
            periodSeconds: 15
          resources:
            requests:
              cpu: "200m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
      volumes:
        - name: model-storage
          persistentVolumeClaim:
            claimName: telco-model-pvc
```

> **`readinessProbe` vs `livenessProbe` — la distinction cruciale** :
> - **Readiness** : "Est-ce que je peux recevoir du trafic maintenant ?" Si elle échoue, le pod est retiré du Service mais N'EST PAS redémarré. Utilisé pendant le chargement du modèle.
> - **Liveness** : "Est-ce que je suis toujours vivant ?" Si elle échoue plusieurs fois, le pod est **tué et redémarré**. Détecte les deadlocks ou crashes silencieux.
>
> On configure la liveness avec un `initialDelaySeconds` plus long et un `periodSeconds` plus large pour éviter de tuer un pod simplement lent.

> **`resources.requests` vs `resources.limits`** :
> - **requests** = ressources réservées au pod, utilisées par le scheduler pour placer le pod sur un nœud
> - **limits** = ressources maximales que le pod peut consommer
>
> Sans `limits`, un pod défaillant pourrait consommer toute la RAM du nœud et faire tomber les autres pods. Sans `requests`, le scheduler ne peut pas garantir une qualité de service.

---

### 6.6 — Service

**Fichier `kubernetes/service.yml`** :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: telcochurn-service
  namespace: telcochurn
spec:
  type: NodePort
  selector:
    app: telcochurn
  ports:
    - protocol: TCP
      port: 8001
      targetPort: 8001
      nodePort: 30081
```

> **Différence `port` / `targetPort` / `nodePort`** :
> - **`port: 8001`** : port exposé par le Service à l'intérieur du cluster
> - **`targetPort: 8001`** : port du conteneur vers lequel le trafic est routé
> - **`nodePort: 30081`** : port ouvert sur chaque nœud du cluster, accessible depuis l'extérieur

---

## Partie 7 — Monitoring

### 7.1 — Configuration Prometheus

**Fichier `monitoring/prometheus/prometheus.yml`** :

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 30s

scrape_configs:
  - job_name: "telcochurn-api"
    scrape_interval: 10s
    static_configs:
      - targets: ["api:8001"]
    metrics_path: /metrics

  - job_name: "prometheus-self"
    static_configs:
      - targets: ["localhost:9090"]
```

> **Pourquoi un job `prometheus-self` ?** Pour monitorer Prometheus lui-même : nombre de séries en mémoire, latence des scrapes, échecs de scrape, etc. Si Prometheus tombe, on aura besoin de ces métriques pour diagnostiquer le problème… mais paradoxalement, c'est Prometheus qui les collecte. En pratique, on a souvent un second Prometheus (federation) qui surveille le premier.

---

### 7.2 — Datasource Grafana

**Fichier `monitoring/grafana/datasources/prometheus.yml`** :

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    isDefault: true
    access: proxy
    editable: true
```

> **`access: proxy`** : Grafana fait lui-même la requête à Prometheus depuis le serveur, puis renvoie le résultat au navigateur. L'alternative `access: direct` ferait faire la requête au navigateur de l'utilisateur, ce qui exposerait Prometheus à l'extérieur — à éviter.

---

### 7.3 — Requêtes PromQL

Les métriques exposées par `prometheus-fastapi-instrumentator` sont nommées `telcochurn_http_requests_total`, `telcochurn_http_request_duration_seconds_bucket`, etc. (préfixe `telcochurn` du namespace défini en 2.3).

**a) Nombre total de prédictions sur `/predict`**

```promql
telcochurn_http_requests_total{handler="/predict"}
```

**b) Taux de requêtes par seconde sur `/predict/batch` sur 5 minutes**

```promql
rate(telcochurn_http_requests_total{handler="/predict/batch"}[5m])
```

**c) Ratio d'erreurs 5xx sur 1 minute, en pourcentage**

```promql
(
  sum(rate(telcochurn_http_requests_total{status=~"5.."}[1m]))
  /
  sum(rate(telcochurn_http_requests_total[1m]))
) * 100
```

> **Décomposition** : numérateur = taux de requêtes 5xx, dénominateur = taux total. Le ratio est multiplié par 100 pour l'exprimer en pourcentage. C'est un indicateur SLO classique : "moins de 1% d'erreurs sur 1 minute".

**d) 99e percentile de latence sur `/predict/batch` sur 10 minutes**

```promql
histogram_quantile(
  0.99,
  rate(telcochurn_http_request_duration_seconds_bucket{handler="/predict/batch"}[10m])
)
```

> **Pourquoi le P99 et pas la moyenne ?** La moyenne masque les outliers. Le P99 dit "99% des requêtes sont plus rapides que cette valeur" — c'est ce qui définit l'expérience utilisateur dans le pire 1% des cas. C'est la métrique de référence en SRE.

**e) Requêtes 401 par minute, segmenté par route**

```promql
sum by (handler) (rate(telcochurn_http_requests_total{status="401"}[1m])) * 60
```

> **Pourquoi `* 60` ?** `rate()` retourne un taux par seconde. Pour avoir un nombre par minute (plus parlant pour ce type de métrique de sécurité), on multiplie par 60.

> **`sum by (handler)`** : agrège les séries en gardant uniquement le label `handler`, et somme toutes les autres dimensions (par exemple si on a plusieurs replicas). Permet d'avoir une série par route.

---

## Récapitulatif des commandes clés

```bash
# Setup environnement local
python3 -m venv venv_telco && source venv_telco/bin/activate
pip install -r api/requirements.txt
python model/train_and_save.py

# Test local de l'API
uvicorn api.main:app --reload --port 8001

# Lancer la stack complète
docker-compose up --build -d
docker-compose logs -f api

# Tests
pytest tests/ --verbose

# Déploiement Kubernetes
kubectl apply -f kubernetes/
kubectl get pods -n telcochurn -w
kubectl rollout status deployment/telcochurn-deployment -n telcochurn

# Accès aux interfaces
# - API       : http://localhost:8001
# - Prometheus: http://localhost:9090
# - Grafana   : http://localhost:3000 (admin / mot de passe du .env)
```
