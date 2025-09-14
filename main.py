name: CI/CD Pipeline

on:
  push:
    branches: ['**']   # trigger on all branches
  pull_request:
    branches: [ master ]

# Default perms are minimal; grant write only where needed
permissions:
  contents: read
  pull-requests: write

env:
  AWS_REGION: us-east-1
  TF_DIR: infra
  K8S_DIR: k8s
  ECR_REPO: fastapi-app
  EKS_CLUSTER: cluster1
  K8S_NAMESPACE: default

jobs:
  # --- Auto PR: <branch> -> master on every push (except master) ---
  auto-pr:
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'push' && github.ref != 'refs/heads/master' }}
    permissions:
      contents: write          # needed to compare & in case future edits write to repo
      pull-requests: write
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Open or update PR to master
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const { owner, repo } = context.repo;
            const head = context.ref.replace('refs/heads/', '');
            const base = 'master';

            const compare = await github.rest.repos.compareCommits({ owner, repo, base, head });
            if (compare.data.status === 'identical' || compare.data.ahead_by === 0) {
              core.info(`No differences between ${head} and ${base}. Skipping PR.`);
              return;
            }

            const { data: existing } = await github.rest.pulls.list({
              owner, repo, state: 'open', head: `${owner}:${head}`, base
            });
            if (existing.length > 0) {
              core.info(`PR already open: #${existing[0].number}`);
              return;
            }

            const title = `Auto PR from ${head}`;
            const body = `This pull request was automatically created from branch \`${head}\` to \`${base}\`.`;
            const { data: pr } = await github.rest.pulls.create({ owner, repo, head, base, title, body, draft: false });
            core.info(`Created PR #${pr.number}`);

  # --- Auto PR: master -> release when pushing to master ---
  auto-pr-master-to-release:
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/master' }}
    permissions:
      contents: write          # REQUIRED to create refs/heads/release
      pull-requests: write
    steps:
      - uses: actions/checkout@v4

      - name: Open or update PR master -> release
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const { owner, repo } = context.repo;
            const head = 'master';
            const base = 'release';

            // Ensure base branch exists (create from master if missing)
            let baseExists = true;
            try {
              await github.rest.git.getRef({ owner, repo, ref: `heads/${base}` });
            } catch (e) {
              baseExists = false;
            }
            if (!baseExists) {
              const { data: masterRef } = await github.rest.git.getRef({ owner, repo, ref: 'heads/master' });
              await github.rest.git.createRef({
                owner, repo,
                ref: `refs/heads/${base}`,
                sha: masterRef.object.sha
              });
              core.info(`Created ${base} branch from master.`);
            }

            // Skip if nothing new on master vs release
            const cmp = await github.rest.repos.compareCommits({ owner, repo, base, head });
            if (cmp.data.status === 'identical' || cmp.data.ahead_by === 0) {
              core.info(`No differences between ${head} and ${base}. Skipping PR.`);
              return;
            }

            // Reuse open PR if present
            const { data: existing } = await github.rest.pulls.list({
              owner, repo, state: 'open', head: `${owner}:${head}`, base
            });
            if (existing.length) {
              core.info(`PR already open: #${existing[0].number}`);
              return;
            }

            const title = `Auto PR: ${head} → ${base}`;
            const body = 'Auto-created after push to master.';
            const { data: pr } = await github.rest.pulls.create({ owner, repo, head, base, title, body, draft: false });
            core.info(`Created PR #${pr.number}`);

  terraform:
    runs-on: ubuntu-latest
    if: >
      ${{
        (github.event_name == 'pull_request' && github.base_ref == 'master') ||
        (github.event_name == 'push' && github.ref == 'refs/heads/master')
      }}
    permissions:
      contents: read
      pull-requests: write
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Install jq
        run: sudo apt-get update && sudo apt-get install -y jq

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_wrapper: false

      - name: Terraform Init
        working-directory: ${{ env.TF_DIR }}
        run: terraform init -upgrade

      - name: Terraform Validate
        working-directory: ${{ env.TF_DIR }}
        run: terraform validate

      - name: Terraform Plan
        id: plan
        working-directory: ${{ env.TF_DIR }}
        shell: bash
        run: |
          set +e
          terraform plan -input=false -detailed-exitcode -out=tfplan
          code=$?
          echo "Terraform exit code: $code"
          echo "exit_code=$code" >> $GITHUB_OUTPUT
          set -e
          if [ "$code" -eq 1 ]; then
            echo "Plan failed"; exit 1
          fi

      - name: Terraform Apply
        if: ${{ github.event_name == 'push' && steps.plan.outputs.exit_code == '2' }}
        working-directory: ${{ env.TF_DIR }}
        run: terraform apply -auto-approve tfplan

  build-and-deploy:
    runs-on: ubuntu-latest
    needs: [terraform]
    if: >
      ${{
        (github.event_name == 'pull_request' && github.base_ref == 'master') ||
        (github.event_name == 'push' && github.ref == 'refs/heads/master')
      }}
    permissions:
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build & Push image
        id: push
        shell: bash
        run: |
          set -e
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          REPOSITORY_URI="$ACCOUNT_ID.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
          IMAGE_TAG="${GITHUB_SHA}"

          docker build -t "${REPOSITORY_URI}:${IMAGE_TAG}" .
          docker push "${REPOSITORY_URI}:${IMAGE_TAG}"

          docker tag "${REPOSITORY_URI}:${IMAGE_TAG}" "${REPOSITORY_URI}:latest"
          docker push "${REPOSITORY_URI}:latest"

          echo "REPOSITORY_URI=${REPOSITORY_URI}" >> $GITHUB_ENV
          echo "IMAGE_TAG=${IMAGE_TAG}" >> $GITHUB_ENV

      - name: Install kubectl
        uses: azure/setup-kubectl@v3

      - name: Update kubeconfig
        run: aws eks update-kubeconfig --region "${AWS_REGION}" --name "${EKS_CLUSTER}"

      - name: Discover RDS endpoint & secret
        id: rds
        run: |
          DB_ID=database-1
          RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" --query 'DBInstances[0].Endpoint.Address' --output text)
          SECRET_ARN=$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)
          echo "endpoint=${RDS_ENDPOINT}"   >> "$GITHUB_OUTPUT"
          echo "secret_arn=${SECRET_ARN}"   >> "$GITHUB_OUTPUT"

      - name: Create/Update K8s resources
        shell: bash
        run: |
          set -euo pipefail
          NS="${K8S_NAMESPACE}"
          SA_NAME="secrets-manager-sa"
          DEPLOY="fastapi-deployment"

          kubectl get ns "${NS}" >/dev/null 2>&1 || kubectl create ns "${NS}"
          kubectl -n "${NS}" get sa "${SA_NAME}" >/dev/null 2>&1 || kubectl -n "${NS}" create sa "${SA_NAME}"

          kubectl -n "${NS}" apply -f k8s/service.yaml || true
          kubectl -n "${NS}" apply -f k8s/deployment.yaml || true

          kubectl -n "${NS}" set image "deployment/${DEPLOY}" fastapi="${REPOSITORY_URI}:${IMAGE_TAG}" --record=true
          kubectl -n "${NS}" set env "deployment/${DEPLOY}" \
            SECRET_NAME='${{ steps.rds.outputs.secret_arn }}' \
            DATABASE_HOST='${{ steps.rds.outputs.endpoint }}' \
            DB_NAME='database_1' \
            AWS_REGION='${{ env.AWS_REGION }}' \
            BOOTSTRAP_ON_START='true'

          kubectl -n "$NS" set serviceaccount "deployment/${DEPLOY}" "${SA_NAME}"
          kubectl -n "${NS}" rollout status "deployment/${DEPLOY}" --timeout=180s

  deploy-to-s3:
    runs-on: ubuntu-latest
    needs: [terraform]
    if: >
      ${{
        (github.event_name == 'pull_request' && github.base_ref == 'master') ||
        (github.event_name == 'push' && github.ref == 'refs/heads/master')
      }}
    permissions:
      contents: read
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        working-directory: frontend/my-react-app
        run: npm install

      - name: Build project
        working-directory: frontend/my-react-app
        run: npm run build

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Getting Account ID
        id: build
        run: |
          set -e
          echo "ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)" >> $GITHUB_ENV

      - name: Sync files to S3
        run: aws s3 sync frontend/my-react-app s3://my-tf-bucket-${{ env.ACCOUNT_ID }}-for-static-website-hosting --delete --exclude "node_modules/*" --exclude "package*.json" --exclude ".git/*" --exclude "public/*" --exclude "src/*"
