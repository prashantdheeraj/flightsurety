pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    uint constant M =  1 ;                              // For Multiparty signature 
    mapping(address => uint256) authorizedCaller;        //Only Authorised Contract (i.e. App contract) can change this
    uint256 private enabled = block.timestamp ;         //This is to use ratelimiting on functions
    uint256 private counter = 1;                        // This is for Re-entrancy guard

    address private contractOwner;                      // Account used to deploy contract
    bool private operational = true;                    // Blocks all state changes throughout the contract if false
    
 
    mapping (address=> uint) airlines;                  // This is list of registered airlines
    mapping (address=> uint) airlineFee ;               // Fee paid by an airline
    uint256 numRegisteredAirline = 0;                   // To find the number of Registered Airline
    mapping (address => address) endorsement;           // Which airline endorsed whom
    mapping (address=> uint) endorsementCount ;         // To track the number of endorsement of an airline for Registration
    

    address[] multiCalls = new address[](0);                //To track multiparty siggnature

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
        authorizedCaller[msg.sender] = 1;
        airlines[firstAirline] = 1;
        numRegisteredAirline++ ;
        endorsement[firstAirline] = msg.sender; // endorsement of the first airline by the contract owner

    }

    /**
    * @dev Event after airline is registered
    *      
    */
    event airlineRegistered(
        address airline
    );

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
        require(authorizedCaller[msg.sender] == 1, "Caller is not authorized");
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
                            requireContractOwner
    {
        require(mode != operational, "New Mode must be different than exisitng mode");
        require(authorizedCaller[msg.sender] == 1, "The user is not authorized");

        bool isDuplicate = false ; //To avoid duplicate voting
        for(uint c= 0; c < multiCalls.length; c++) {
            if (multiCalls[c] == msg.sender){
                isDuplicate = true;
                break;
            }
        }

        require(!isDuplicate, "Caller has already called this function");
        multiCalls.push(msg.sender);

        if(multiCalls.length >= M){
            operational = mode;
            multiCalls = new address[](0);
        }
    }

    /**
    * @dev Authorize the app contract to make changes
    *
    * When a contract is not authhorized it cannot make changes to this contract
    */ 
    function authorizeCaller (address dataContract) external requireContractOwner {
        authorizedCaller[dataContract] = 1;
    }

    /**
    * @dev DeAuthorize  a contract to make any changes
    *
    * When a contract is not authhorized i.e it has an upgraded the previous version is deleted so that its not authorized. 
    */ 
    function deAuthorizedCaller (address dataContract) external requireContractOwner {
        delete authorizedCaller[dataContract]; 
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
                            
    {
        // means there needs to be a persistent mapping of airline
        //its should be mapping of an address belonging to an airline
        
        require(airlines[endorsingAirline] == 1, "The Endorser is not a Registered airlines");
        require(endorsement[newAirline] == endorsingAirline, "The endorser has already endorsed once"); 

        endorsementCount[newAirline] = endorsementCount[newAirline].add(1); //Increase the endorsementcount by 1

        uint minimumEndorsement = numRegisteredAirline.div(2);
        
        if(numRegisteredAirline >4 && endorsementCount[newAirline] >= minimumEndorsement) {
            airlines[newAirline] = 1 ;
            numRegisteredAirline++ ; 
            emit airlineRegistered(newAirline);     //  emit an airline registered event
        }

        if(numRegisteredAirline <4) {
            airlines[newAirline] = 1 ;
            numRegisteredAirline++ ; 
            emit airlineRegistered(newAirline);     //  emit an airline registered event
        }
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
        if(airlines[airline] == 1){
            return true; 
        } else {
            return false; 
        }
    
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (                             
                            )
                            external
                            payable
    {
        //the parmaeter passed should be flight id etc
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
        //Pay the money to the airline
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
    {
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
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
        fund();
    }


}

