
let Randname :string = "Hello";

console.log(Randname + " World!");

const stockName:string = "RELIANCE";
let myURL:string = `https://query1.finance.yahoo.com/v8/finance/chart/${stockName}.NS`;

async function getAPIdata(){
    try{
        let response = await fetch(myURL);
        if (!response.ok)
            throw new Error("No response Recieved");
        const data = await response.json();
        console.log(JSON.stringify(data, null, 2));
    
    }catch(e){
        console.log("An error occured: " + e);
    }
}
// could have also written it as: const getAPIdata = async () => {bla bla}
getAPIdata();
