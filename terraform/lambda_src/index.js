exports.handler = async (event) => {
    console.log("Event received:", JSON.stringify(event));
    return {
        statusCode: 200,
        body: JSON.stringify({ message: "Alert triggered." })
    };
};
