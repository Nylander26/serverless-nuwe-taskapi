const AWS = require('aws-sdk');
const s3 = new AWS.S3({
    endpoint: 'http://host.docker.internal:4566',
    accessKeyId: 'test',
    secretAccessKey: 'test',
    s3ForcePathStyle: true,
    region: 'us-east-1'
});

exports.handler = async () => {
    const bucketName = 'taskstorage';
    const fileName = `task_${Date.now()}.txt`;
    const fileContent = 'This is a scheduled task execution.';

    const params = {
        Bucket: bucketName,
        Key: fileName,
        Body: fileContent,
    };

    try {
        await s3.putObject(params).promise();
        return {
            statusCode: 200,
            body: JSON.stringify({ message: 'Scheduled task executed successfully', fileName }),
        };
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Failed to execute scheduled task', error }),
        };
    }
};
