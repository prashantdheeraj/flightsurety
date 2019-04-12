pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

     
    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    // uint constant M =  2 ;                              // For Multiparty signature 
    address[] multiCalls = new address[](0);            //To track multiparty siggnature
    
    mapping (address => address[]) public endorsement;           // Which airline endorsed whom
    uint public minimumEndorsement ;                              //min endorsement required
    uint public endorsementRequired ;                            //Num endorsement required for registration
    //mapping (address=> uint) public endorsementCount ;         // To track the number of endorsement of an airline for Registration

    uint public minimumFund = 10 ether;                     // minimum funding amount by an airline

    
    address private contractOwner;          // Account used to deploy contract

    FlightSuretyData flightSuretyData ;     // Access the Data contract

    mapping (address=> uint) airlineFeePaid ;               // Fee paid by an airline

 
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
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
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
    * @dev Modifier that requires an airline to be registered
    */
    modifier requireIsRegistered() {
        require(
            flightSuretyData.isRegistered(msg.sender),
            "Airline must be registered before being able to perform this action"
        );
        _;
    }

        /**
    * @dev Modifier that requires an airline to be registered
    */
    modifier requireHasPaidFee() {
        require(
            flightSuretyData.hasPaidFee(msg.sender),
            "Airline must fund before able to perform this action"
        );
        _;
    }

    /**
    * @dev Modifier that checks if an airline has sufficient funs
    */
    modifier requireSufficientFund() {
        require(msg.value >= minimumFund, "Minimun funding amount is 10 ETH");
        _;
    }

    /**
    * @dev Modifier the checks if insurance amount is within the lower and upper limit
    */

      modifier requireAmountWithinLimits(uint amount, uint lowerLimit, uint upperLimit) {
        require(amount < upperLimit, "Value higher than max not allowed");
        require(amount > lowerLimit, "Value lower than min not allowed");
        _;
    }

     /**
    * @dev Modifier the checks if the amount paid is more than the insurance premium
    */
    modifier requireMoreThanInsurancePremium(uint insurancePremium) {
        require(msg.value >= insurancePremium, "Value sent does not cover the price!");
        _;
    }

     /**
    * @dev Modifier the checks if the amount paid is more than the insurance premium
    */
    modifier requireAmountReturnCheck(uint ticketCost) {
        uint amountToReturn = msg.value - ticketCost;
        msg.sender.transfer(amountToReturn);
        _;
    }



    /**
    * @dev Modifier to check for multisig Criteria
    */
    modifier requireMultiSigCheck(){
    //    require(minimumSigReq > flightSuretyData.numRegisteredAirline().div(2), "Multi Signature Failed");

        bool isDuplicate = false ; //To avoid duplicate voting
        for(uint c= 0; c < multiCalls.length; c++) {
            if (multiCalls[c] == msg.sender){
                isDuplicate = true;
                break;
            }
        }
        require(!isDuplicate, "Caller has already called this function");
        multiCalls.push(msg.sender);

        if(multiCalls.length > flightSuretyData.numRegisteredAirline().div(2)){
            _;   
            multiCalls = new address[](0);
        }
       
    }


    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address dataContract
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
        //endorsement[firstAirline] = msg.sender; // endorsement of the first airline by the contract owner

    }

    event flightRegistered(address airline, string flightCode, uint landTime);
    event flightProcessed(string flightCode, string destination, uint timestamp, uint8 statusCode);
    event amountClaimed(address beneficiary);

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return (flightSuretyData.isOperational());  // Modify to call data contract's status
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
                            requireMultiSigCheck
    {
      flightSuretyData.setOperatingStatus(mode);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                            (  
                                address newAirline
                            )
                            requireIsRegistered
                            requireHasPaidFee
                            external
                           
    {       
        // only first Airline can register a new airline when less than 4 airlines are registered
        if (flightSuretyData.numRegisteredAirline() < 4) {
           flightSuretyData.registerAirline(newAirline,msg.sender);
        } else {

            bool endorsed = false;

            for (uint i=0; i < endorsement[newAirline].length; i++) {
                if (endorsement[newAirline][i] == msg.sender) {
                    endorsed = true;
                    break;
                }
            }
            require(!endorsed, "The endorser has already endorsed once");
            endorsement[newAirline].push(msg.sender) ; // Add the endorsement in the endorsement table

            minimumEndorsement = flightSuretyData.numRegisteredAirline().div(2);
            endorsementRequired = minimumEndorsement.sub(endorsement[newAirline].length);  

            if (endorsementRequired == 0) {
                endorsement[newAirline] = new address[](0);
                flightSuretyData.registerAirline(newAirline,msg.sender);  
            }
        }
        
    }

     /**
    * @dev Number of endorsement left for registration
    *
    */

    function endorsementNeeded(address newAirline)
    public
    view
    returns (uint additionalEndorsement)
    {
        uint endorsementreceived = endorsement[newAirline].length;
        uint threshold = flightSuretyData.numRegisteredAirline().div(2);
        additionalEndorsement = threshold.sub(endorsementreceived);
    }

    /**
    * @dev To provide fund (more than minimum ) by an airline
    *
    */ 
    function fund() 
        external
        requireIsOperational
        requireIsRegistered
        requireSufficientFund
        payable
    {
        flightSuretyData.fund.value(msg.value)(msg.sender);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
   function registerFlight
    (
        bool isRegistered,
        uint status,
        string flightCode,
        string origin,
        string destination,
        uint startTime,
        uint landTime,        
        uint ticketCost
        
    )
    external
    requireIsOperational
    requireHasPaidFee
    {

        flightSuretyData.registerFlight(
            isRegistered,
            status,
            flightCode,
            origin,
            destination,
            startTime,
            landTime,
            ticketCost, 
            msg.sender
        );
        emit flightRegistered(msg.sender , flightCode, landTime);
    }

    function getFlightIdentifier
                        (
                            string flightCode,
                            string destination,
                            uint256 landTime
                        )
                        view
                        internal
                        returns(bytes32) 
    {
        return flightSuretyData.getFlightIdentifier(flightCode,destination,landTime);
    }


 
    /**
    * @dev Buy insurance for a flight
    *
    */  

    function bookTicketAndBuyInsurance
                        (
                            string flightCode,
                            string destination,
                            uint landTime,
                            uint amountPaid                            
                        )
                        external
                        requireAmountWithinLimits(amountPaid, 0, 1.05 ether) // +0.05 to cover gas costs
                        requireMoreThanInsurancePremium(flightSuretyData.getFlightPrice(getFlightIdentifier(flightCode, destination, landTime)).add(amountPaid))
                        requireAmountReturnCheck(flightSuretyData.getFlightPrice(getFlightIdentifier(flightCode, destination, landTime)).add(amountPaid))
                        requireIsOperational
                        payable
            {
                bytes32 flightKey= flightSuretyData.getFlightIdentifier(flightCode, destination, landTime);
                flightSuretyData.bookTicketAndBuyInsurance.value(msg.value)(flightKey, amountPaid.mul(3).div(2), msg.sender);          
            }

    /**
    * @dev CAmount claimed by the beneficiary (Passeneger or an airline)
    *
    */  
    function claimAmount()
    external
    requireIsOperational
    {
        flightSuretyData.pay(msg.sender);
        emit amountClaimed(msg.sender);
    }

   
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
    (
        string flightCode,
        string destination,
        uint256 timestamp,
        uint8 statusCode
    )
    internal
    requireIsOperational
    {
        // generate flightIdentifier
        bytes32 flightIdentifier = getFlightIdentifier(flightCode, destination, timestamp);
        flightSuretyData.processFlightStatus(flightIdentifier, statusCode);
        emit flightProcessed(flightCode, destination, timestamp, statusCode);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp                            
                        )
                        external
                        returns (bytes32)
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
        return key;
    } 



// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle is registered
    event OracleRegistered(uint8[3] indexes);

    // Event fired each time an oracle submits a response
    event FlightStatusInfo( string flight, string destination,  uint256 timestamp, uint8 status);

    event OracleReport( string flight, string destination, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
        emit OracleRegistered(indexes);
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            string flight,
                            string destination,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(flight, destination, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(flight, destination, timestamp, statusCode);
        
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(flight, destination, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(flight, destination, timestamp, statusCode);
        }
    }


    
    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}  


/***************************************************** */
// FlightSuretyData Interface Contract
/**************************************************** */

contract FlightSuretyData {

    struct Airline{
        bool registered; 
        bool feePaid;
    }                                                   // Struct variable to capture status of an airlien
    mapping (address=> Airline) public airlines;        // This is list of registered airlines
    uint256 public numRegisteredAirline ;            // To find the number of Registered Airline

   function isOperational() public view returns(bool) ;

   function setOperatingStatus (bool mode) external ;
 
   function isRegistered(address airlineAddress) external view returns (bool); 

   function hasPaidFee(address airlineAddress) external view returns (bool);

   function registerAirline (  
                                address newAirline,
                                address endorsingAirline
                            )
                            external ;

   function fund (address fundingAddress) public payable;

    function registerFlight (
        bool isRegistered,
        uint statusCode,
        string flightCode,
        string origin,
        string destination,
        uint startTime,
        uint landTime,
        uint ticketCost,
        address airlineAddress
    )  external; 

    function getFlightIdentifier 
                        (
                            string flightCode,
                            string destination,
                            uint256 landTime
                        )
                        pure
                        external
                        returns(bytes32);

    function getFlightPrice(bytes32 flightIdentifier) external view returns (uint) ;

    function bookTicketAndBuyInsurance
                        (
                                bytes32 flightIdentifier, 
                                uint insuranceAmount, 
                                address passengerAddress                             
                        )
                        external
                        payable  ;  

    function pay(address beneficiary) external;
   
    function processFlightStatus(bytes32 flightKey, uint8 status)  external;
 }
