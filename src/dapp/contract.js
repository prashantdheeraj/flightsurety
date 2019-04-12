import FlightSuretyData from '../../build/contracts/FlightSuretyData.json'
import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {


    constructor (network, callback) {
    
        let config = Config[network]
        // Inject web3
        if (window.ethereum) {
          // use metamask's providers
          // modern browsers
          this.web3 = new Web3(window.ethereum)
          // Request accounts access
          try {
            window.ethereum.enable()
          } catch (error) {
            console.error('User denied access to accounts')
          }
        } else if (window.web3) {
          // legacy browsers
          this.web3 = new Web3(web3.currentProvider)
        } else {
          // fallback for non dapp browsers
          this.web3 = new Web3(new Web3.providers.HttpProvider(config.url))
        }
    
        
      

        // Load contract
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress)
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress)
        //console.log(this.flightSuretyApp);
        this.initialize(callback)
        //this.account = null
        //console.log(this.account)
      }
    

    initialize (callback) {
      this.web3.eth.getAccounts((error, accts) => {
        if (!error) {
          this.account = accts[0]
          this.firstAirline = accts[1]
          callback()
        } else {
          console.error(error)
        }
      })
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.account}, callback);
    }

    async isAuthorizedCaller(callback) {
      let self = this;
      //console.log(self.account)
      try{
        await self.flightSuretyData.methods
        .isAuthorizedCaller(self.account)  
        .call({ from: self.account}, callback);
       
      }catch (error) {
         
      }
    }

    async authoriseUser(address){
      try {
        await this.flightSuretyData.methods
          .authorizeCaller(address)
          .send({ from: this.account,
                  gas: 1500000,
                  gasPrice: '30000000000000'
           })
           return {
            result: 'user Authorised',
            error: ''
          }
      } catch (error) {
        return {
          result: 'could not authorise',
          error: error
        }
      }

    }

    async fetchFlightStatus (flight, destination, landing) {
        try {
          const key = await this.flightSuretyApp.methods
                            .fetchFlightStatus(flight, destination, landing)
                            .send({ from: this.account,
                                    gas: 1500000,
                                    gasPrice: '30000000000000'
                            })
            return{
              key : key
            }
        } catch (error) {
          return {
            key: error
          }
        }
      }
    
      async registerAirline (airline) {
        try {
          console.log(this.account)
          await this.flightSuretyApp.methods
            .registerAirline(airline)
            .send({ from: this.account,
                    gas: 4712388,
                    gasPrice: 100000000000
            })
          const endorsementRequired = await this.flightSuretyApp.methods
            .endorsementNeeded(airline)
            .call()
          //  call()
          return {
            address: this.account,
            votes: endorsementRequired
          }
        } catch (error) {
          return {
            error: error
          }
        }
      }
    
      async registerFlight (flightCode,
        origin,
        destination,
        startTime,
        landTime,
        ticketCost ) {
        try {
          const priceWei = this.web3.utils.toWei(ticketCost.toString(), 'ether')
          await this.flightSuretyApp.methods
            .registerFlight(true, 0, flightCode, origin, destination, startTime, landTime,  priceWei)
            .send({ from: this.account,
                  gas: 4712388,
                  gasPrice: 100000000000
             })
          const flightIdentifier = await this.flightSuretyData.methods.getFlightIdentifier(flightCode,destination,landTime).call({ from: this.account})
          return {
            flightIdentifier: flightIdentifier,
            error: ''
          }
        } catch (error) {
          return {
            flightIdentifier: 'Not returned',
            error: error
          }
        }
      }
    
      fund (amount, callback) {
        let self = this
        console.log(self.account);
        self.flightSuretyApp.methods
          .fund()
          .send({
            from: self.account,
            gas: 4712388,
            gasPrice: 100000000000,
            value: self.web3.utils.toWei(amount, 'ether')
          }, (error, result) => {
            callback(error, { address: self.account, amount: amount })
          })
      }
    
      async book (flight, to, landing, price, insurance) {
        let total = +price + +insurance
        total = total.toString()
        const amount = this.web3.utils.toWei(insurance.toString(), 'ether')
        try {
          await this.flightSuretyApp.methods
            .bookTicketAndBuyInsurance(flight, to, +landing, amount)
            .send({
              from: this.account,
              gas: 4712388,
              gasPrice: 100000000000,
              value: this.web3.utils.toWei(total.toString(), 'ether')
            })
          return { passenger: this.account }
        } catch (error) {
          console.log(error)
          return {
            error: error
          }
        }
      }
    
      async withdraw () {
        await this.flightSuretyApp.methods
          .claimAmount()
          .send({ from: this.account,
            gas: 4712388,
            gasPrice: 100000000000 })
      }
}
    