
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;

  // Operations and Settings

  const minFund = web3.utils.toWei('10', 'ether')               // Note: .toWei() returns a string
  const insurancePayment = web3.utils.toWei('0.1', 'ether')     // Note .toWei() returns a string
  const ticketPrice = web3.utils.toWei('0.5', 'ether')          // Note .toWei() returns a string
  const takeOff = Math.floor(Date.now() / 1000) + 1000
  const landing = takeOff + 1000
  const from = 'HAM'
  const to = 'PAR'
  const flightRef = 'AF0187'


  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  //TEST : (Passed)
  it('First account is the firstAirline', async () => {
    let isAirline = await config.flightSuretyData.isAirline.call(config.firstAirline) ; //Call gives the result. Without call its an object
    //console.log("The first account is : " + config.firstAirline);
    //console.log(isAirline);
    assert.equal(isAirline, true, "The Account 1 is not configured as first airline")
  })
  
  //TEST : (Passed)
  it(`Has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  //TEST : (Passed)
  it(`Can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

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

  //TEST : (Passed)
  it(`Can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(accessDenied,  { from: config.owner });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

   //Test : (Passed)
   it('Can allow Contract owner change operational status', async function () {
    await config.flightSuretyData.setOperatingStatus(false,{ from: config.owner })
    assert.equal(await config.flightSuretyData.isOperational.call(), false, 'Failed to change operational status')

    //Revert back operational status to True for other test
    await config.flightSuretyData.setOperatingStatus(true,{ from: config.owner })
  })

  //TEST : (Passed)
  it(`Can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false, { from: config.owner });

      let reverted = false;
      try 
      {
          await config.flightSuretyData.registerAirline.call(accounts[3],config.owner);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  //TEST: Passed
  it('Can add an address to list of authorized callers', async () => {
    await config.flightSuretyData.authorizeCaller(config.testAddresses[2],{from: config.owner});
    let isAuthorizedCaller = await config.flightSuretyData.isAuthorizedCaller.call(config.testAddresses[2])
    assert.equal(isAuthorizedCaller, true, "An address cannot be added to the Authorized caller list")
  })

  //TEST: Passed
  it('Can Registers first airline at deployment', async () => {
    const firstAirline = await config.flightSuretyData.airlines(config.firstAirline);
    assert.equal(firstAirline.registered, true, "Unable to register the first airline during deployment")
  })

  //TEST: Passed
  it('Cannot allow an airline to Register another if it has not provided funding', async () => {
    try {
      let errorMsg = false
      await config.flightSuretyApp.registerAirline(accounts[2], {from: config.firstAirline});
    } catch (error) {
      errorMsg = error.message.includes('Airline must fund before able to perform this action');
    }
    assert.equal(errorMsg, true, "A registered Airline can register another airline without paying funds")
  })

  //TEST: Passed
  it('Can allow airline to provide the fund', async () => {
  
    const zeroBalance = await web3.eth.getBalance(config.flightSuretyData.address)   // Fund is strored in the Data Contract address. Fetch the initial fund amount
    const airline = await config.flightSuretyData.airlines(config.firstAirline)
    // console.log(zeroBalance);
    // console.log(airline.registered);
    // console.log(airline.feePaid);
    //assert(airline.feePaid, 'The Airline has not paid the fee')

    try{
      await config.flightSuretyApp.fund({ from: config.firstAirline, value: minFund }) // First airline provides with minimum fund
    }
    catch (error) {
      console.log(error.message)
    }
   
    const balanceFund = await web3.eth.getBalance(config.flightSuretyData.address)   // Now the balance in data contract account should be increased by minimum fund
    //console.log(balanceFund);
    assert.equal(+balanceFund, +minFund, 'Minimum fund has not been transferred')
  })

  //TEST : Passed
  it('Can register an Airline using registerAirline() if has funded', async () => {

    let newAirline = accounts[2];
    // firstAirline has already provided fund in previous test
    await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    let result = await config.flightSuretyData.isAirline.call(newAirline); 
    assert.equal(result, true, "Airline was not able to register even if it has provided the fund");

  });
  
  //TEST: FAILED
  it('Can allow a new airline to register only if 50% registered airline endorse.', async () => {
    // register 2 new airlines and fund it
    await config.flightSuretyApp.registerAirline( accounts[3], { from: config.firstAirline })
    await config.flightSuretyApp.fund({ from: accounts[3], value: minFund })

    await config.flightSuretyApp.registerAirline( accounts[4], { from: config.firstAirline })
    await config.flightSuretyApp.fund({ from: accounts[4], value: minFund })
   
    //console.log(await config.flightSuretyData.numRegisteredAirline.call())
    assert.equal(await config.flightSuretyData.numRegisteredAirline.call(), 4)

    
    // First airline fails to register 5th one without if 50% endorsement is not there
    try {
      await config.flightSuretyApp.registerAirline(accounts[5], { from: config.firstAirline })
    } catch (error) {
      //console.log(error);
      //assert(error.message.includes('50% endorsement is not there for registration'), 'Error: wrong revert message1.1')
    }

    // Endorser cannot vote twice
    try {
       await config.flightSuretyApp.registerAirline(accounts[5], { from: config.firstAirline })
    } catch (error) {
       //console.log(error);
       assert(error.message.includes('The endorser has already endorsed once'), 'Error: wrong revert message2')
    }
    
     // third airline fails to register 5th one without multisig
     try {
      await config.flightSuretyApp.registerAirline(accounts[5], { from: accounts[3] })
    } catch (error) {
      //console.log(error);
      //assert(error.message.includes('50% endorsement is not there for registration'), 'Error: wrong revert message1.2')
    }

    // By this time 50% registration is there
     // third airline fails to register 5th one without multisig
     try {
      await config.flightSuretyApp.registerAirline(accounts[5], { from:   accounts[4] })
    } catch (error) {
      //console.log(error);
      //assert(error.message.includes('50% endorsement is not there for registration'), 'Error: wrong revert message1.3')
    }
    //console.log(await config.flightSuretyApp.minimumEndorsement())
    //console.log(await config.flightSuretyApp.endorsementRequired())
  
    //console.log(await config.flightSuretyApp.endorsement(accounts[5],{from:config.firstAirline}));

  
    // Let second other airline vote
    //Making airline 2 to fund and allow airline 5 to endore
    await config.flightSuretyApp.fund({ from: accounts[2], value: minFund })

    await config.flightSuretyApp.registerAirline(accounts[5], { from: accounts[2] })

    airline = await config.flightSuretyData.airlines.call(accounts[5])
    assert(await airline.registered, 'Error: 5th airline was not registered')
  })


  //TEST : 6 (Failed)
  it('function call is made when multi-party threshold is reached', async () => {

    // //ARRANGE
    // let admin1 = accounts[2];
    // let admin2 = accounts[3];
    // let admin3 = accounts[4];

    // // await config.flightSuretyApp.registerAirline(admin1, true, {from: config.owner});
    // // await config.flightSuretyApp.registerAirline(admin2, true, {from: config.owner});
    // // await config.flightSuretyApp.registerAirline(admin3, true, {from: config.owner});

    // await config.flightSuretyApp.registerAirline(admin1,  {from: config.owner});
    // await config.flightSuretyApp.registerAirline(admin2,  {from: config.owner});
    // await config.flightSuretyApp.registerAirline(admin3,  {from: config.owner});

    let startStatus = await config.flightSuretyApp.isOperational.call();
    console.log("The start status is: " + startStatus);
    let changeStatus = !startStatus;
    console.log("The change status for testing is: " + changeStatus);

    //ACT
    await config.flightSuretyApp.setOperatingStatus(changeStatus, {from: accounts[2]});
    await config.flightSuretyApp.setOperatingStatus(changeStatus, {from: accounts[3]});
    await config.flightSuretyApp.setOperatingStatus(changeStatus, {from: accounts[4]});
    await config.flightSuretyApp.setOperatingStatus(changeStatus, {from: accounts[5]});

    let newStatus = await config.flightSuretyApp.isOperational.call();
    console.log("The new status is: " + newStatus);

    //ASSERT
    assert.equal(changeStatus, newStatus, "Multi-Party call failed");
  });
 

});
