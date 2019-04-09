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
        airlines[firstAirline].registered = true;
        numRegisteredAirline = 1  ; //First Airline registered
        
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
    function isAuthorizedCaller (address caller) external returns (bool) {
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
                            requireIsCallerAuthorized
                          
    {
                
        require(airlines[endorsingAirline].registered == true, "The Endorser is not a Registered airlines");
        require(airlines[endorsingAirline].feePaid == true, "The Endorser has not paid the fee");

        airlines[newAirline].registered = true ;
        airlines[newAirline].feePaid = false ;
        numRegisteredAirline = numRegisteredAirline.add(1) ; 
        emit airlineRegistered(newAirline,endorsingAirline);     //  emit an airline registered event
        
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
                                address fundingAddress  
                            )
                            public
                            requireIsOperational
                            requireIsCallerAuthorized
                            payable
    {
        airlines[fundingAddress].feePaid = true;
        emit providedFund(fundingAddress);
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
        fund(msg.sender);
    }


}

