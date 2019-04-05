
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

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        //await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
         await config.flightSuretyApp.registerAirline(newAirline, config.firstAirline);
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('function call is made when multi-party threshold is reached', async () => {

    //ARRANGE
    let admin1 = accounts[1];
    let admin2 = accounts[2];
    let admin3 = accounts[3];

    // await config.flightSuretyApp.registerAirline(admin1, true, {from: config.owner});
    // await config.flightSuretyApp.registerAirline(admin2, true, {from: config.owner});
    // await config.flightSuretyApp.registerAirline(admin3, true, {from: config.owner});

    await config.flightSuretyApp.registerAirline(admin1, config.owner);
    await config.flightSuretyApp.registerAirline(admin2, config.owner);
    await config.flightSuretyApp.registerAirline(admin3, config.owner);

    let startStatus = await config.flightSuretyApp.isOperational.call();
    let changeStatus = !startStatus;

    //ACT
    await config.flightSuretyData.setOperatingStatus(changeStatus, {from: admin1});
    await config.flightSuretyData.setOperatingStatus(changeStatus, {from: admin2});

    let newStatus = await config.flightSuretyApp.isOperational.call();

    //ASSERT
    assert.equal(changeStatus, newStatus, "Multi-Party call failed");
  });
 

});
