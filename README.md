# E-commerce Data Platform — Terraform IaC

Kurs Data Engineering | Miesiąc 3 | Cloud & Terraform

## Architektura

```
AWS (eu-north-1)
├── S3: kurs-de-aleksander-ortonowski-dev-raw          (landing zone, versioning+SSE)
├── S3: kurs-de-aleksander-ortonowski-dev-processed     (po transformacji ETL)
├── S3: kurs-de-aleksander-ortonowski-dev-curated       (dane dla analityków)
├── S3: kurs-de-aleksander-ortonowski (state)           (remote state Terraform)
├── DynamoDB: terraform-state-lock                      (state locking)
├── RDS: PostgreSQL 15.13 (db.t3.micro, dev)             + parameter group
├── IAM Role: glue-orders-role                           (least-privilege, tworzona przez moduł)
├── Glue Job: orders-etl-job                             (PySpark, JOIN orders+customers)
└── Glue Trigger: orders-etl-trigger (CRON, wyłączony)

Terraform
└── module "glue_job"     ← reużywalny moduł (zajęcia 3)
```

## Prerequisity

- AWS CLI skonfigurowane: `aws configure --profile ecommerce-dev` (region `eu-north-1`)
- Terraform >= 1.7.0: `terraform --version`
- Uprawnienia IAM na koncie: S3, IAM, Glue, RDS, EC2 (Security Groups), DynamoDB
- Bucket dla state i tabela DynamoDB już istnieją (patrz sekcja Bootstrap)

## Bootstrap — jednorazowy setup

```bash
# Bucket dla Terraform state (jeśli jeszcze nie istnieje)
aws s3api create-bucket \
  --bucket kurs-de-aleksander-ortonowski \
  --region eu-north-1 \
  --create-bucket-configuration LocationConstraint=eu-north-1 \
  --profile ecommerce-dev

# Tabela DynamoDB dla locka stanu
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --profile ecommerce-dev \
  --region eu-north-1
```

## Uruchomienie

```bash
# 1. Skopiuj i uzupełnij zmienne (NIGDY nie commituj terraform.tfvars!)
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# uzupełnij: db_username, db_password, vpc_id, private_subnet_ids

# 2. Init, plan, apply
cd terraform/
terraform init
terraform plan -var="env=dev" -out=tfplan
terraform apply tfplan

# 3. Weryfikacja idempotentności
terraform plan -var="env=dev"
# oczekiwany wynik: "No changes. Your infrastructure matches the configuration."
```

## Moduły

- `modules/glue_job` — AWS Glue Job z conditional IAM Role (`count`), opcjonalnym
  Glue Trigger (CRON), przyjmuje zewnętrzną rolę IAM lub tworzy własną

## Troubleshooting

**1. `InvalidClientTokenId` przy dowolnej komendzie `aws`/`terraform`**
Access Key jest nieważny albo profil ma zły region. Sprawdź:
```bash
aws configure list --profile ecommerce-dev
aws sts get-caller-identity --profile ecommerce-dev
```
Jeśli zwraca błąd — wygeneruj nowe klucze w IAM Console i uruchom `aws configure --profile ecommerce-dev` ponownie.

**2. `Backend initialization required` / `Error: validating provider credentials`**
Blok `backend "s3"` potrzebuje własnego `profile`, niezależnie od `provider "aws" { profile = ... }` —
bez tego Terraform próbuje użyć profilu `default`. Upewnij się, że `main.tf` ma:
```hcl
backend "s3" {
  ...
  profile = "ecommerce-dev"
}
```
Po zmianie backendu zawsze `terraform init -reconfigure`.

**3. `InvalidParameterValue: Character sets beyond ASCII are not supported` (Security Group)**
Pole `description` w `aws_security_group` (i inne pola API EC2) nie akceptuje polskich znaków
diakrytycznych. Używaj czystego ASCII w opisach zasobów wysyłanych do AWS — polskie znaki są
bezpieczne tylko w komentarzach `#` i `description` zmiennych Terraform (te nigdy nie trafiają do API).

**4. `InvalidParameterCombination: Cannot find version X.Y for postgres`**
AWS regularnie wycofuje stare minor version silników RDS. Sprawdź dostępne wersje przed `apply`:
```bash
aws rds describe-db-engine-versions --engine postgres \
  --query 'DBEngineVersions[?starts_with(EngineVersion, `15.`)].EngineVersion' \
  --profile ecommerce-dev --region eu-north-1
```

**5. `AccessDenied` na `ec2:CreateSecurityGroup`**
Domyślne uprawnienia z setupu kursu (S3, IAM, Glue, RDS) nie obejmują EC2, a Security Group
dla RDS tego wymaga. Dodaj polityce użytkownika: `AmazonEC2FullAccess`.

## Powiązanie z poprzednimi miesiącami

| Miesiąc | Co stworzyłeś | Jak używa M3 |
|---------|--------------|--------------|
| M1 — SQL | Schema PostgreSQL (customers, orders, products) | RDS w M3 to ta sama baza, provisowana przez Terraform |
| M2 — Python ETL | Logika transformacji (cast, DQ, dedup) | `orders_etl.py` w M3 to ta sama logika, na Glue + JOIN z customers |
| M3 — Terraform | Infrastruktura chmurowa (ten projekt) | M4 Airflow będzie ją orchestrować (`orders_etl_job_name` output) |

## Ostatnie 20 linii `terraform apply` (dowód działania)

```
module.orders_etl.aws_glue_job.this: Creation complete after 1s [id=orders-etl-job]
module.orders_etl.aws_glue_trigger.schedule[0]: Creating...
module.orders_etl.aws_iam_role_policy_attachment.glue_service[0]: Creation complete after 1s [id=glue-orders-role-20260803182056508100000002]
module.orders_etl.aws_iam_role_policy.glue_s3[0]: Creation complete after 1s [id=glue-orders-role:glue-orders-s3]
module.orders_etl.aws_glue_trigger.schedule[0]: Creation complete after 0s [id=orders-etl-trigger]

Apply complete! Resources added, 0 changed, 0 destroyed.

Outputs:

orders_etl_job_name = "orders-etl-job"
rds_db_name = "ecommerce"
rds_endpoint = <sensitive>
rds_replica_endpoint = <sensitive>
rds_security_group_id = "sg-xxxxxxxxxxxxxxxxx"
s3_curated_bucket = "kurs-de-aleksander-ortonowski-dev-curated"
s3_processed_bucket = "kurs-de-aleksander-ortonowski-dev-processed"
s3_raw_bucket = "kurs-de-aleksander-ortonowski-dev-raw"
```
