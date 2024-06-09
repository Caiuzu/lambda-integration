#!/bin/bash

# Parar execução em caso de erro
set -e

# Detalhes das lambdas
LAMBDAS=(
  "example-lambda,index.handler,nodejs18.x,arn:aws:iam::000000000000:role/lambda-role"
  # Adicione mais lambdas aqui se necessário
)

# Caminho para o diretório das lambdas
LAMBDA_DIR="localstack/lambdas"

# Esperar o LocalStack estar pronto
until awslocal lambda list-functions
do
  echo "Waiting for LocalStack Lambda..."
  sleep 3
done

# Criar funções Lambda no LocalStack
for LAMBDA_INFO in "${LAMBDAS[@]}"; do
  IFS=',' read -r LAMBDA_NAME HANDLER RUNTIME ROLE <<< "$LAMBDA_INFO"

  ZIP_NAME="$LAMBDA_DIR/$LAMBDA_NAME.zip"
  LAMBDA_CODE_DIR="$LAMBDA_DIR/$LAMBDA_NAME"

  # Verificar se o diretório da lambda existe
  if [ -d "$LAMBDA_CODE_DIR" ]; then
    # Navegar até o diretório da lambda
    cd $LAMBDA_CODE_DIR

    # Criar o ZIP no diretório pai
    echo "Creating ZIP for $LAMBDA_NAME"
    zip -r "../$LAMBDA_NAME.zip" ./*

    # Voltar ao diretório raiz do projeto
    cd ../../../

    # Verificar se o grupo de logs existe
    if ! awslocal logs describe-log-groups --log-group-name-prefix "/aws/lambda/$LAMBDA_NAME" | grep -q "/aws/lambda/$LAMBDA_NAME"; then
      # Criar grupo de logs
      awslocal logs create-log-group --log-group-name /aws/lambda/$LAMBDA_NAME
    else
      echo "Log group /aws/lambda/$LAMBDA_NAME already exists. Skipping creation."
    fi

    # Criar função Lambda no LocalStack
    echo "Creating Lambda function $LAMBDA_NAME"
    if awslocal lambda create-function \
      --function-name $LAMBDA_NAME \
      --runtime $RUNTIME \
      --role $ROLE \
      --handler $HANDLER \
      --zip-file fileb://$ZIP_NAME; then
      echo "Lambda function '$LAMBDA_NAME' created and configured successfully in LocalStack."
    else
      echo "Lambda function '$LAMBDA_NAME' already exists. If you want to recreate it, delete the function first."
    fi
  else
    echo "Directory $LAMBDA_CODE_DIR does not exist. Skipping..."
  fi
done
