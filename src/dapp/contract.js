import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.appAddress = config.appAddress; 
        this.dataAddress = config.dataAddress;
        this.airlines = [];
        this.passengers = [];
        this.flights = ["AB123", "CD456", "EF789"];
        this.owner = null;
        this.initialize(callback);
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            let accnt;
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            this.authorizeCaller();
            callback();
        });

    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    authorizeCaller() {
        let self = this;
        self.flightSuretyData.methods
            .authorizeCaller(self.appAddress)
            .send({ from: self.owner }, function(err, res) {
              if (err) {
                console.log("An error occured");
              }
              console.log("Is Authorized: " , res);
            });
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: 1649129486
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner }, (error, result) => {
                callback(error, payload);
            });
    }

    registerAirline(airline, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .registerAirline(airline)
            .send({ from: self.owner, gas: 6721900 }, callback);
    }

    fundAirline(airline, callback) {
        let self = this;
        const fee = this.web3.utils.toWei('10', 'ether');
        self.flightSuretyApp.methods
            .fundAirline()
            .send({ from: airline, value: fee, gas: 6721900 }, callback);
    }

    registerFlight(airline, flight, timestamp, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .registerFlight(flight, timestamp)
            .send({ from: airline, gas: 6721900 }, callback);
    }

    buyInsurance(passenger, amount, airline, flight, timestamp, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .buyInsurance(airline, flight, timestamp)
            .send({ from: passenger, gas: 6721900, value: this.web3.utils.toWei(amount, 'ether') }, callback);
    }

    withdrawInsurance(passenger, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .withdraw()
            .send({ from: passenger, gas: 6721900 }, callback);
    }

    



}