import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import "core-js/stable";
import "regenerator-runtime/runtime";


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
/*
flightSuretyApp.methods.isOperational().call(function(err, res) {
  if (err) {
    console.log("An error occured");
  }
  console.log("Is Operational: " , res);
});
*/

const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;

let fee = 1000000000000000000;
let ORACLES_COUNT = 20;
async function registerOracles() {
  let accounts = await web3.eth.getAccounts();

  console.log("Registering Oracles...");
  const fee = await flightSuretyApp.methods.getRegistrationFee().call();
  console.log("Registration fee", fee);
  
  for(let a=1; a<ORACLES_COUNT; a++) {
    try {

      await flightSuretyApp.methods
          .registerOracle()
          .send({from: accounts[a], value: fee, gas:3000000});
      console.log("Registered oracle ", a, accounts[a]);
    } catch (e) {
      console.log(e);
    }
  }
}

registerOracles();

async function submitOracleResponse(airline, flight, timestamp) {
    let accounts = await web3.eth.getAccounts();
    for(let a=1; a < ORACLES_COUNT; a++) {

      // Get oracle information
      let oracleIndexes = await flightSuretyApp.methods
                                .getMyIndexes()
                                .call({ from: accounts[a], gas:3000000});


      for(let idx=0;idx<3;idx++) {

        try {
          // Submit a response...it will only be accepted if there is an Index match
          // console.log(oracleIndexes[idx], airline, flight, timestamp, STATUS_CODE_LATE_AIRLINE);
          await flightSuretyApp.methods
                .submitOracleResponse(oracleIndexes[idx], airline, flight, timestamp, STATUS_CODE_LATE_AIRLINE)
                .send( { from: accounts[a], gas:3000000 });
          // console.log("successful");
        }
        catch(e) {
          // console.log(e);
          // Enable this when debugging
          // console.log('\nError', idx, oracleIndexes[idx].toNumber(), flight, timestamp);
        }
      }
    }

    let result = await flightSuretyData.methods.getFlightStatus(airline, flight, timestamp)
              .call({ from: accounts[0] , gas:3000000});
    console.log("is Late: ", result);
}

flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event);

    submitOracleResponse(event.returnValues.airline, event.returnValues.flight, event.returnValues.timestamp);
});

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


