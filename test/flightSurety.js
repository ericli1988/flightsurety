
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
    const TEST_ORACLES_COUNT = 30;

    const STATUS_CODE_UNKNOWN = 0;
    const STATUS_CODE_ON_TIME = 10;
    const STATUS_CODE_LATE_AIRLINE = 20;
    const STATUS_CODE_LATE_WEATHER = 30;
    const STATUS_CODE_LATE_TECHNICAL = 40;
    const STATUS_CODE_LATE_OTHER = 50;

  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);

  });


  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyApp.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  /*
  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });
  */

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, {from: accounts[0]});
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner"); 
  });

  it('one vote cannot change operating status but enough votes can', async function () {
    //await config.flightSuretyData.setOperatingStatus(false, {from: accounts[0]});
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

    await config.flightSuretyData.setOperatingStatus(false, { from: accounts[1]});
    await config.flightSuretyData.setOperatingStatus(false, { from: accounts[2]});
    await config.flightSuretyData.setOperatingStatus(false, { from: accounts[3]});
    status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, false, "Incorrect initial operating status value");

  })


  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      //await config.flightSuretyData.setOperatingStatus(false, { from: accounts[0]});

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true, { from: accounts[0]});
      await config.flightSuretyData.setOperatingStatus(true, { from: accounts[1]});
      await config.flightSuretyData.setOperatingStatus(true, { from: accounts[2]});
      await config.flightSuretyData.setOperatingStatus(true, { from: accounts[3]});

  });

  it('first airline is registered', async function () {
    let result = await config.flightSuretyData.isAirlineRegistered.call(config.firstAirline); 

    // ASSERT
    assert.equal(result, true, "First airline is registered when contract is deployed");

  })

  it('can register an airline until there are four airlines', async function () {
    await config.flightSuretyApp.registerAirline(accounts[2], { from: config.firstAirline });
    await config.flightSuretyApp.registerAirline(accounts[3], { from: config.firstAirline });
    await config.flightSuretyApp.registerAirline(accounts[4], { from: config.firstAirline });
    let result1 = await config.flightSuretyData.isAirlineRegistered.call(accounts[2]); 
    let result2 = await config.flightSuretyData.isAirlineRegistered.call(accounts[3]); 
    let result3 = await config.flightSuretyData.isAirlineRegistered.call(accounts[4]); 
    // ASSERT
    assert.equal(result1, true, "Second airline is registered");
    assert.equal(result2, true, "Third airline is registered");
    assert.equal(result3, true, "Fourth airline is registered");

  })


  it('cannot register 5th airline without multiparty consensus', async function () {
    await config.flightSuretyApp.registerAirline(accounts[5], { from: config.firstAirline });
    let result = await config.flightSuretyData.isAirlineRegistered.call(accounts[5]); 

    assert.equal(result, false, "Fifth airline is not registered without consensus");
  })


  it('can register 5th airline with multiparty consensus', async function () {
    // await config.flightSuretyApp.registerAirline(config.testAddresses[5], { from: config.firstAirline });
    await config.flightSuretyApp.registerAirline(accounts[5], { from: accounts[2] });
    let result = await config.flightSuretyData.isAirlineRegistered.call(accounts[5]); 

    assert.equal(result, true, "Fifth airline is registered with consensus");
  })


  it('airline can pay 10 wei to become active', async function () {
    let result0 = await config.flightSuretyData.isAirlineFunded.call(accounts[1]);
    assert.equal(result0, false, "Airline is not funded before funding");
    
    await config.flightSuretyApp.fundAirline({from: accounts[1], value: web3.utils.toWei("10", "ether")});
    let result = await config.flightSuretyData.isAirlineFunded.call(accounts[1]);
    assert.equal(result, true, "Airline is funded");

    let reverted = false;
      try 
      {
          await config.flightSuretyApp.fundAirline({from: accounts[1], value: web3.utils.toWei("10", "ether")});
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Airline cannot be funded again");    

    // fund the other airlines
    await config.flightSuretyApp.fundAirline({from: accounts[2], value: web3.utils.toWei("10", "ether")});
    await config.flightSuretyApp.fundAirline({from: accounts[3], value: web3.utils.toWei("10", "ether")});
    await config.flightSuretyApp.fundAirline({from: accounts[4], value: web3.utils.toWei("10", "ether")});
    // await config.flightSuretyApp.fundAirline({from: accounts[5], value: web3.utils.toWei("10", "ether")});

  })

  it('airline can register flights', async function() {
    let result0 = await config.flightSuretyData.isFlightRegistered.call("AB721");
    assert.equal(result0, false, "Flight is not registered");

    await config.flightSuretyApp.registerFlight("AB721", 1649129486, {from: config.firstAirline});

    let result1 = await config.flightSuretyData.isFlightRegistered.call("AB721");
    assert.equal(result1, true, "Flight is registered");
  })

  it('unfunded airline cannot register flights', async function() {
    let reverted = false;
    try {
      await config.flightSuretyApp.registerFlight("AB722", 1649129486, {from: accounts[5]});
    } catch (e) {
      reverted = true;
    }
    assert.equal(reverted, true, "Unfunded airline cannot register flights");
  })

  it('passenger can buy insurance', async function() {
    await config.flightSuretyApp.buyInsurance(config.firstAirline, "AB721", 1649129486, {from: accounts[6], value: web3.utils.toWei("0.1", "ether")});
    let result = await config.flightSuretyData.isInsured.call(config.firstAirline, "AB721", 1649129486, accounts[6]);
    assert.equal(result, true, "Passenger bought insurance");
    let result1 = await config.flightSuretyData.getInsuredAmount.call(config.firstAirline, "AB721", 1649129486, accounts[6]);
    assert.equal(result1, web3.utils.toWei("0.1", "ether"), "Insurance amount is correctly recorded");
  })



  it('can register oracles', async () => {
    
    // ARRANGE
    let fee = await config.flightSuretyApp.getRegistrationFee.call();

    // ACT
    for(let a=1; a<TEST_ORACLES_COUNT; a++) {      
      await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });
      let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a]});
      console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
    }


  });

  it('can request flight status', async () => {
    
    // ARRANGE
    let flight = 'AB721'; // Course number
    let timestamp = 1649129486; //Math.floor(Date.now() / 1000);
    let airline = config.firstAirline;

    // Submit a request for oracles to get status information for a flight
    await config.flightSuretyApp.fetchFlightStatus(airline, flight, timestamp);
    // ACT

    // Since the Index assigned to each test account is opaque by design
    // loop through all the accounts and for each account, all its Indexes (indices?)
    // and submit a response. The contract will reject a submission if it was
    // not requested so while sub-optimal, it's a good test of that feature
    for(let a=1; a<TEST_ORACLES_COUNT; a++) {

      // Get oracle information
      let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a]});
      for(let idx=0;idx<3;idx++) {

        try {
          // Submit a response...it will only be accepted if there is an Index match
          await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], config.firstAirline, flight, timestamp, STATUS_CODE_LATE_AIRLINE , { from: accounts[a] });

        }
        catch(e) {
          // Enable this when debugging
           // console.log('\nError', idx, oracleIndexes[idx].toNumber(), flight, timestamp);
        }
      }
    }

    let result = await config.flightSuretyData.getFlightStatus.call(airline, flight, timestamp);
    assert.equal(result, true, "flight is late");
  });

  it('passenger is credited', async() => {
    let payout = await config.flightSuretyData.getInsurancePayout.call(accounts[6]);
    assert.equal(Number(payout), web3.utils.toWei("0.15", "ether"), "payout amount is correct");
  });

  it('passenger withdraws insurance', async() => {
    let balanceBeforePay = await web3.eth.getBalance(accounts[6]);
    let result = await config.flightSuretyApp.withdraw({from: accounts[6]});
    // let result = await config.flightSuretyData.pay(accounts[6], {from: accounts[6]});
    let balanceAfterPay = await web3.eth.getBalance(accounts[6]);

    console.log("insurance received", balanceAfterPay - balanceBeforePay );

    let gasPrice = await web3.eth.getGasPrice();
    let gasUsed = result.receipt.gasUsed;
    assert.equal(balanceAfterPay > balanceBeforePay, true, "User has withdrawn payout to his wallet");

    console.log("gas used", gasUsed);
    console.log("gas Price", gasPrice);
    console.log("gas paid", gasUsed * gasPrice);
    let payout = await config.flightSuretyData.getInsurancePayout.call(accounts[6]);
    assert.equal(Number(payout), 0, "payout to be paid is reduced to 0");

  });

  /*

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {
    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('airline can be registered if properly funded', async () => {

    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline, value: web3.utils.toWei(String(11), "ether")});
    }
    catch(e) {
      console.log(e);
        console.log("does not pass");
    }

    let result = await config.flightSuretyData.isAirline.call(newAirline); 
    
    let airlines = await config.flightSuretyData.readAirlines.call();
    console.log("Airlines:");
    console.log(airlines);
    // ASSERT
    assert.equal(result, true, "Airline should be able to register");


  });
 */

});
