const AWS = require('aws-sdk');
const crypto = require('crypto');
const dynamoDB = new AWS.DynamoDB.DocumentClient({
    endpoint: 'http://host.docker.internal:4566', 
    region: 'us-east-1', 
    credentials: {
        accessKeyId: 'test', 
        secretAccessKey: 'test' 
    }
});

exports.handler = async (event) => {
    const { task_name, cron_expression } = JSON.parse(event.body);
    const task_id = crypto.randomUUID();

    const taskNameBase64 = Buffer.from(task_name).toString('base64');
    const cronExpressionBase64 = Buffer.from(cron_expression).toString('base64');

    const params = {
        TableName: 'taskapi', 
        Item: {
            task_id,
            task_name: taskNameBase64,
            cron_expression: cronExpressionBase64
        },
    };

    try {
        await dynamoDB.put(params).promise();
        return {
            statusCode: 200,
            body: JSON.stringify({ message: 'Task created successfully', task_id }),
        };
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Failed to create task', error }),
        };
    }
};
