pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    mapping(address => bool) authorizedCaller;          //Only Authorised Contract  can change this

    uint256 private enabled = block.timestamp ;         //This is to use ratelimiting on functions

    uint256 private counter = 1;                        // This is for Re-entrancy guard

    address private contractOwner;                      // Account used to deploy contract
    bool private operational = true;                    // Blocks all state changes throughout the contract if false
    
    struct Airline{
        bool registered; 
        bool feePaid;
    }                                                   // Struct variable to capture status of an airlien
    mapping (address=> Airline) public airlines;        // This is list of registered airlines
    uint256 public numRegisteredAirline ;            // To find the number of Registered Airline

   
    struct Flight {
        bool isRegistered;
        uint statusCode;
        string flightCode;
        string origin;
        string desitination;
        uint256 flightTime;
        uint256 landTime;
        uint ticketCost;
        address airline;
        mapping(address => bool) bookings;
        mapping(address => uint) insurances;
    }                                                // Flights


    mapping(bytes32 => Flight) public flights;
    bytes32[] public flightIdentifiers;
    uint public indexFlightIdentifiers = 0;

    address[] internal passengers;
    mapping(address => uint) public claimAmount;

   
   

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address firstAirline
                                ) 
                                public 
    {
        contractOwner = msg.sender;

        
        authorizedCaller[msg.sender] = true; // Authorize the contract owner

        // first airline registration during deployment
        airlines[msg.sender].registered = true; // Register the contract owner in airlines mapping to make it work from DAPP. The request sender must be registered.
        airlines[msg.sender].feePaid = true;
        
        airlines[firstAirline].registered = true;
        numRegisteredAirline = 1  ; //First Airline registered. Do not count the contract owner
        
    }

    /**
    * @dev Event after airline is registered
    *      
    */
    event airlineRegistered(address newAirline, address endorsingAirline);

    /**
    * @dev Event after airline has provide fund
    *      
    */
    event providedFund(address fundingAddress);

    /**
    * @dev Event after ticket is booked
    *      
    */
    event bookingDone(bytes32 flightIdentifier,address passengerAddress);   

    /**
    * @dev Event after ticket is booked
    *      
    */
    event insurancePurchased(bytes32 flightIdentifier,address passengerAddress, uint amount);   

     /**
    * @dev Amount Credited to the PAssenger
    *      
    */
    event amountCredited(address passenger, uint amount);

     /**
    * @dev Amount Paid to Passeneger
    *      
    */
    event amountPaid(address beneficiary, uint amount);
   
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier that requires the Contract to be Authorized
    */
    modifier requireIsCallerAuthorized()
    {
        require(authorizedCaller[msg.sender] == true, "Caller is not authorized");
        _;
    }

    /**
    * @dev Modifier that requires the Flight to be Registered
    */
    modifier requireIsFlightRegistered(bytes32 flightIdentifier)
    {
        require(flights[flightIdentifier].isRegistered , "The Flight is not registered");
        _;
    }

    /* 
    * @dev Modifier that requires the Flight to be Registered
    */
    modifier requiredNotProcessesForPayment(bytes32 flightIdentifier) {
        require(flights[flightIdentifier].statusCode == 0, "This flight has already been processed for payment");
        _;
    }

 
    /**
    * @dev Modifier for rate limititng a function
    */
    modifier requireRateLimit(uint time) {
        require(block.timestamp >= enabled, "Rate Limiting in Effect");
        enabled = enabled.add(time);
        _;
    }

     /**
    * @dev Modifier to protect from re-entrency
    */
    modifier requireEntrancyGuard(){
        counter = counter.add(1);
        uint256 guard = counter;
        _;
        require(guard == counter, "This is not allowed");
    }


    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            //requireContractOwner
    {
        //require(mode != operational, "New Mode must be different than exisitng mode");
        require(authorizedCaller[msg.sender] == true, "The user is not authorized");
        operational = mode;
       
    }

    /**
    * @dev Authorize the app contract to make changes
    *
    * When a contract is not authhorized it cannot make changes to this contract
    */ 
    function authorizeCaller (address caller) external requireContractOwner {
        authorizedCaller[caller] = true;
    }

    /**
    * @dev DeAuthorize  a contract to make any changes
    *
    * When a contract is not authhorized i.e it has an upgraded the previous version is deleted so that its not authorized. 
    */ 
    function deAuthorizedCaller (address caller) external requireContractOwner {
        delete authorizedCaller[caller]; 
    }

    /**
    * @dev DeAuthorize  a contract to make any changes
    *
    * When a contract is not authhorized i.e it has an upgraded the previous version is deleted so that its not authorized. 
    */ 
    function isAuthorizedCaller (address caller) public view  returns (bool) {
        return authorizedCaller[caller]; 
    }



     /**
    * @dev This function returns a Boolean whether an airline has paid fee or not
    **/
    function hasPaidFee(address airlineAddress) external view returns (bool feePaid)
    {
        feePaid = airlines[airlineAddress].feePaid;
    }


     /**
    * @dev This function returns a Boolean whether an airline is registered or 
    **/
    function isRegistered(address airlineAddress) external view returns (bool isRegistered)
    {
        isRegistered = airlines[airlineAddress].registered;
    }

    /**
    * @dev Checks if an airlines is registerd
    *     
    */   
    function isAirline
                            (   
                                address airline
                            )
                            external
                            returns (bool)
                            
    {
       return airlines[airline].registered ; 
    }

         /**
    * @dev get a flight identifier.
    *
    */  
    function getFlightIdentifier
                        (
                            string flightCode,
                            string destination,
                            uint256 landTime
                        )
                        pure
                        public
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(flightCode, destination, landTime));
    }
   


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (   
                                address newAirline,
                                address endorsingAirline
                            )
                            external
                            requireIsOperational
                            //requireIsCallerAuthorized
                          
    {
                
        require(airlines[endorsingAirline].registered == true, "The Endorser is not a Registered airlines");
        require(airlines[endorsingAirline].feePaid == true, "The Endorser has not paid the fee");

        airlines[newAirline].registered = true ;
        airlines[newAirline].feePaid = false ;
        numRegisteredAirline = numRegisteredAirline.add(1) ; 
        emit airlineRegistered(newAirline,endorsingAirline);     //  emit an airline registered event
        
    }

   /**
    * @dev Register a future flight for insuring.
    */  
    function registerFlight
    (
        bool isRegistered,
        uint statusCode,
        string flightCode,
        string origin,
        string destination,
        uint startTime,
        uint landTime,
        uint ticketCost,
        address airlineAddress
    )
    external
    requireIsOperational
    //requireIsCallerAuthorized
    {
        require(startTime > now, "The Flight time has to be in future");
        require(landTime > startTime, "The lading time is earlier than the takeoff time");

        Flight memory flight = Flight(
            isRegistered,
            statusCode,
            flightCode,
            origin,
            destination,
            startTime,
            landTime,
            ticketCost,
            airlineAddress
        );

        bytes32 flightIdentifier = keccak256(abi.encodePacked(flightCode, destination, landTime));

        flights[flightIdentifier] = flight;
        indexFlightIdentifiers = flightIdentifiers.push(flightIdentifier).sub(1);
        
    }

    /**
    * @dev get the ticket price of a flight
    *
    */

    function getFlightPrice(bytes32 flightIdentifier)
    external
    view
    returns (uint ticketCost)
    {
        ticketCost = flights[flightIdentifier].ticketCost;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function bookTicketAndBuyInsurance
                            (
                                    bytes32 flightIdentifier, 
                                    uint amount, 
                                    address passengerAddress                             
                            )
                            external
                            requireIsOperational
                            //requireIsCallerAuthorized
                            requireIsFlightRegistered(flightIdentifier)
                            payable
    {
        Flight storage flight = flights[flightIdentifier];          //get the flight with the identifier
        flight.bookings[passengerAddress] = true;                   // Set the booking as true  
        emit bookingDone(flightIdentifier,passengerAddress);       // emit event ticket booked
        flight.insurances[passengerAddress] = amount;            // make the isnurace amount as paid
        emit insurancePurchased(flightIdentifier,passengerAddress,amount);       // emit event ticket booked
        
        passengers.push(passengerAddress);
        claimAmount[flight.airline] = flight.ticketCost;            // This is for the airline to claim the ticket amount

    }


     /*
    *@dev To check if passenger has purchased a ticket or not.
    */  
    function hasPurchasedFlightTicket
    (
        string flightCode,
        string destination,
        uint256 landTime,
        address passenger
    )
    public
    view
    returns(bool purchased)
    {
        bytes32 flightIdentifier = getFlightIdentifier(flightCode, destination, landTime);
        Flight storage flight = flights[flightIdentifier];
        purchased = flight.bookings[passenger];
    }

      /*
    *@dev To check if passenger has purchased insurance or not.
    */

    function hasPurchasedInsurance
    (
        string flightCode,
        string destination,
        uint256 landTime,
        address passenger
    )
    public
    view
    returns(uint amount)
    {
        bytes32 flightIdentifier = getFlightIdentifier(flightCode, destination, landTime);
        Flight storage flight = flights[flightIdentifier];
        amount = flight.insurances[passenger];
    }

    /**
     *  @dev Credits payouts to insurees
    */
        
    function creditInsurees(bytes32 flightIdentifier)
    internal
    requireIsOperational
    requireIsFlightRegistered(flightIdentifier)
    {
        
        Flight storage flight = flights[flightIdentifier];   // Find the flight


        // loop over passengers and credit them their insurance amount
        
        for (uint i = 0; i < passengers.length; i++) {
            claimAmount[passengers[i]] = flight.insurances[passengers[i]];
            emit amountCredited(passengers[i], flight.insurances[passengers[i]]);
        }    
    }

    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address beneficiary)
    external
    requireIsOperational
    //requireIsCallerAuthorized
    {
        // Check-Effect-Interaction pattern to protect against re entrancy attack
        // Check
        require(claimAmount[beneficiary] > 0, "No amount to be transferred to this address");
        // Effect
        uint amount = claimAmount[beneficiary];
        claimAmount[beneficiary] = 0;
        // Interaction
        beneficiary.transfer(amount);
        emit amountPaid(beneficiary, amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            ( 
                                address fundingAddress  
                            )
                            public
                            requireIsOperational
                            //requireIsCallerAuthorized
                            payable
    {
        airlines[fundingAddress].feePaid = true;
        emit providedFund(fundingAddress);
    }

    /**
    * @dev Check the flight status.
    *
    */
   
    function processFlightStatus
    (
        bytes32 flightIdentifier,
        uint8 statusCode
    )
    external
    requireIsFlightRegistered(flightIdentifier)
    requireIsOperational
    //requireIsCallerAuthorized
    requiredNotProcessesForPayment(flightIdentifier)
    {
        // Check (modifiers)
        Flight storage flight = flights[flightIdentifier];
        // Effect
        flight.statusCode = statusCode;
        // Interact
        // 20 = "flight delay due to airline"
        if (statusCode == 20) {
            creditInsurees(flightIdentifier);
        }
    }


    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        
        require(msg.data.length == 0, "this is not allowed");
        fund(msg.sender);
    }


}

