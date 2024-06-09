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
const payload = { body: JSON.stringify({ num1: 3, num2: 4 }) };

// Invocar a função Lambda
invoke(funcName, payload).catch((error) => {
  console.error("Error invoking Lambda function:", error.message);
});
