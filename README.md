# Lambda Integration

<!--Banner e logo-->

<div align="center">
<img src="https://awsmp-logos.s3.amazonaws.com/d23d1bcc-cfe5-4301-893b-8f30025074e4/f5a016996213129265ed0eb248157749.png">
</div>

<!-- Badges -->
<p align="center">
   <a href="https://www.linkedin.com/in/caiuzu/">
      <img alt="Caio Souza" src="https://img.shields.io/badge/-Caio Souza-755ceb?style=flat&logo=Linkedin&logoColor=white" />
   </a>
  <img alt="GitHub language count" src="https://img.shields.io/github/languages/count/caiuzu/lambda-integration?color=6c87f7"/>
  <img alt="Repository size" src="https://img.shields.io/github/repo-size/caiuzu/lambda-integration?color=6a76f3"/>
</p>


---

## Índice

1. [Instalar o AWS CLI e LocalStack CLI](#1-instalar-o-aws-cli-e-localstack-cli)
2. [Configurar o Docker Compose](#2-configurar-o-docker-compose)
3. [Estrutura de Diretórios](#3-estrutura-de-diretórios)
4. [Criar o Código da Lambda](#4-criar-o-código-da-lambda)
5. [Criar o Script de Configuração do LocalStack](#5-criar-o-script-de-configuração-do-localstack)
6. [Iniciar o Docker Compose e Configurar o LocalStack](#6-iniciar-o-docker-compose-e-configurar-o-localstack)
7. [Comandos Úteis para Interagir com a Lambda](#7-comandos-úteis-para-interagir-com-a-lambda)
8. [Código para Invocar a Lambda com Node.js](#8-código-para-invocar-a-lambda-com-nodejs)
9. [Instalar Dependências](#9-instalar-dependências)
10. [Executar o Código](#10-executar-o-código)
11. [Verificar a Resposta](#11-verificar-a-resposta)
12. [Referências](#12-referências)

---

## 1. Instalar o AWS CLI e LocalStack CLI

### AWS CLI:

Siga as instruções para instalar o AWS CLI: [AWS CLI Installation](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

### LocalStack CLI:

Siga as instruções para instalar o LocalStack CLI: https://docs.localstack.cloud/getting-started/installation/

### LocalStack Desktop:

Siga as instruções para instalar o LocalStack Desktop: https://docs.localstack.cloud/user-guide/tools/localstack-desktop/

---

## 2. Configurar o Docker Compose

Crie um arquivo `docker-compose.yml` na raiz do seu projeto:

```yaml
version: '3.7'

services:
  localstack:
    container_name: "${LOCALSTACK_DOCKER_NAME:-localstack-container}"
    image: localstack/localstack:latest
    ports:
      - "127.0.0.1:4566:4566"            # LocalStack Gateway
      - "127.0.0.1:4510-4559:4510-4559"  # external services port range
    environment:
      - DEBUG=${DEBUG:-0}
      - SERVICES=lambda,logs
      - LAMBDA_REMOTE_DOCKER=false
      - REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    volumes:
      - "${LOCALSTACK_VOLUME_DIR:-./volume}:/var/lib/localstack"
      - "/var/run/docker.sock:/var/run/docker.sock"
```

---

## 3. Estrutura de Diretórios

Certifique-se de ter a seguinte estrutura de diretórios e arquivos:

```
seu-projeto
├── docker-compose.yml
└── localstack
    ├── setup-localstack.sh
    └── lambdas
        └── example-lambda
            └── index.js
```

---

## 4. Criar o Código da Lambda

**Arquivo: `localstack/lambdas/example-lambda/index.js`**

```js
exports.handler = async (event) => {
    let body = JSON.parse(event.body);
    const product = body.num1 * body.num2;
    const response = {
        statusCode: 200,
        body: "The product of " + body.num1 + " and " + body.num2 + " is " + product,
    };
    return response;
};
```

---

## 5. Criar o Script de Configuração do LocalStack

**Arquivo: `localstack/setup-localstack.sh`**

```sh
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
```

Dê permissão de execução ao script:

```sh
chmod +x localstack/setup-localstack.sh
```

---

## 6. Iniciar o Docker Compose e Configurar o LocalStack

Inicie os serviços:

```sh
docker-compose up -d
```

Execute o script de configuração (a partir da raiz do projeto):

```sh
./localstack/setup-localstack.sh
```

---

## 7. Comandos Úteis para Interagir com a Lambda

**Consultar Lambda:**

```sh
awslocal lambda invoke --function-name example-lambda --cli-binary-format raw-in-base64-out --payload '{"body": "{\"num1\": 3, \"num2\": 4}"}' response.json
```

**Criar Lambda:**

```sh
awslocal lambda create-function \
    --function-name example-lambda \
    --runtime nodejs18.x \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler index.handler \
    --zip-file fileb://localstack/lambdas/example-lambda.zip
```

**Listar Lambdas:**

```sh
awslocal lambda list-functions
```

**Listar Lambda Específica:**

```sh
awslocal lambda get-function --function-name example-lambda
```

**Aguardar até que o Status seja Ativo:**

```sh
awslocal lambda wait function-active-v2 --function-name example-lambda
```

**Deletar Lambda Específica:**

```sh
awslocal lambda delete-function --function-name example-lambda
```

**Verificar Logs da Lambda:**

```sh
awslocal logs tail /aws/lambda/example-lambda
```

**Verificar Logs do Container LocalStack:**

```sh
docker logs localstack-container
```

**Criar Grupo de Logs:**

```sh
awslocal logs create-log-group --log-group-name /aws/lambda/example-lambda
```

**Verificar Logs em um Grupo de Logs:**

```sh
awslocal logs describe-log-streams --log-group-name /aws/lambda/example-lambda
```

**Lambda Logs Stream:**

```sh
awslocal logs get-log-events --log-group-name /aws/lambda/example-lambda --log-stream-name <LOG_STREAM_NAME>
```

Substitua `<LOG_STREAM_NAME>` pelo nome do stream de logs retornado pelo comando anterior.

---

## 8. Código para Invocar a Lambda com Node.js

**Arquivo: `index.js`**

```javascript
import { InvokeCommand, LambdaClient, LogType } from "@aws-sdk/client-lambda";

// Função para invocar a Lambda
const invoke = async (funcName, payload) => {
  const client = new LambdaClient({ endpoint: 'http://localhost:4566' });
  const command = new InvokeCommand({
    FunctionName: funcName,
    Payload: JSON.stringify(payload),
    LogType: LogType.Tail,
  });

  const { Payload, LogResult } = await client.send(command);

  const result = Buffer.from(Payload).toString();
  const logs = Buffer.from(LogResult, "base64").toString();

  console.log("Result:", result);
  console.log("Logs:", logs);
  
  return { logs, result };
};

// Nome da função Lambda e payload
const funcName = 'example-lambda';
const payload = { body

: JSON.stringify({ num1: 3, num2: 4 }) };

// Invocar a função Lambda
invoke(funcName, payload).catch((error) => {
  console.error("Error invoking Lambda function:", error.message);
});
```

---

## 9. Instalar Dependências

Certifique-se de que as dependências necessárias estão instaladas:

```sh
npm install @aws-sdk/client-lambda
```

---

## 10. Executar o Código

Execute o script para invocar a Lambda:

```sh
node index.js
```

---

## 11. Verificar a Resposta

Verifique a saída no terminal para ver o resultado da invocação da função Lambda.

---

## 12. Referências

- [AWS CLI Installation](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- [LocalStack Installation](https://docs.localstack.cloud/getting-started/installation/#docker-compose)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/latest/dg/urls-tutorial.html)
- [AWS SDK for JavaScript - Lambda Invoke Example](https://github.com/awsdocs/aws-doc-sdk-examples/blob/main/javascriptv3/example_code/lambda/actions/invoke.js)

---

<h4 align=center>Desenvolvido por Caio Souza <a href="https://www.linkedin.com/in/caiuzu/"> <strong>Entre em contato</strong> ;D</a></h4>
