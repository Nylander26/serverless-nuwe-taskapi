const AWS = require('aws-sdk');
const dynamoDB = new AWS.DynamoDB.DocumentClient({
    endpoint: 'http://host.docker.internal:4566', 
    region: 'us-east-1', 
    credentials: {
        accessKeyId: 'test', 
        secretAccessKey: 'test' 
    }
});
exports.handler = async () => {
    const params = {
        TableName: 'taskapi',
    };

    try {
        const data = await dynamoDB.scan(params).promise();

        const tasks = data.Items.map(task => ({
            ...task,
            task_name: task.task_name ? Buffer.from(task.task_name, 'base64').toString('utf-8') : null,
            cron_expression: task.cron_expression ? Buffer.from(task.cron_expression, 'base64').toString('utf-8') : null,
        }))

        return {
            statusCode: 200,
            body: JSON.stringify({ tasks }),
        };
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Failed to list tasks', error }),
        };
    }
};
