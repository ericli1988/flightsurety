
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

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

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

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
      await config.flightSuretyData.setOperatingStatus(true);

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
