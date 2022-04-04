pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    struct airline {
        uint id;
        bool isRegistered;
        bool isFunded;
    }

    mapping(address => airline) private airlines;                                // Mapping for storing airlines
    address[] private registeredAirlines = new address[](0);
    
    uint constant M = 4;
    uint airlineSize = 0;
    uint256 registrationFee = 10 wei;

    // Restrict data contract callers
    mapping(address => uint256) private authorizedContracts;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event AirlineRegistered(address addr);

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
        airlines[firstAirline] = airline({id: 0, 
                                        isRegistered: true, 
                                        isFunded: false});
        registeredAirlines.push(firstAirline);
        airlineSize++;
    }

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

    // Define a modifier that checks if the paid amount is sufficient to cover the price
    modifier paidEnough(uint256 _price) { 
        require(msg.value >= _price); 
        _;
    }
  
    // Define a modifier that checks the price and refunds the remaining balance
    modifier checkValue(address newAirline) {
        _;
        uint _price = registrationFee;
        uint amountToReturn = msg.value - _price;
        newAirline.transfer(amountToReturn);
    }

    modifier canOnlyBeCalledByApp() {
        _;
    }

    /**
    * @dev Modifier that requires function caller to be authorized
    */
    modifier requireIsCallerAuthorized() {
        require(authorizedContracts[msg.sender] == 1, "Caller is not authorized");
        _;
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
        operational = mode;
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
                                address _airline
                            )
                            external
                            requireIsCallerAuthorized
                            returns(bool)
    {
        airlines[_airline] = airline({id: registeredAirlines.length, 
                                        isRegistered: true, 
                                        isFunded: false});
        registeredAirlines.push(_airline);
        // emit AirlineRegistered(_airline);
        return true;
    }

    function fundAirline(address _airline)
                        external
                        canOnlyBeCalledByApp
                        // payable
                        // paidEnough(registrationFee)
                        // checkValue(airline) 
    {

    }

    /**
    *      Check if airline is registered
    *      
    *
    */   
    function isAirlineRegistered
                        (
                            address _airline
                        )
                        external
                        view
                        returns(bool)
    {
        
        for (uint i=0; i < registeredAirlines.length; i++) {
            if (_airline == registeredAirlines[i]) {
                return true;
            }    
        }
        
        return false;
    }

/*
    function numberOfAirlines() 
        external 
        returns(uint) 
    {
        return registeredAirlines.length;
    }
*/

    function getRegisteredAirlines()
        external
        returns(address[] memory)
    {
        return registeredAirlines;
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
                            address _airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(_airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


    /**
    * @dev Adds address to authorized contracts
    */
    function authorizeCaller(address contractAddress) external requireContractOwner {
        authorizedContracts[contractAddress] = 1;
    }

    /**
    * @dev Removes address from authorized contracts
    */
    function deauthorizeCaller(address contractAddress) external requireContractOwner {
        delete authorizedContracts[contractAddress];
    }

}

