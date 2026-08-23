
let stockName = "RELIANCE"
let myURL = `https://query1.finance.yahoo.com/v8/finance/chart/${stockName}.NS`

async function getAPIdata(){
    try{
        let response = await fetch(myURL);
        if (!response.ok)
            throw new Error("No response Recieved");
        const data = await response.json();
        console.log(data);
        console.log(JSON.stringify(data, null, 2));
    }
    catch(error){
        console.error(error);
    }
}

getAPIdata();