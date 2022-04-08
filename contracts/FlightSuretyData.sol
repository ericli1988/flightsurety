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

    struct flight {
        string flight_num;
        uint256 arrival_timestamp;
        address airline;
        bool isRegistered;
    }

    mapping(address => airline) private airlines;                                // Mapping for storing airlines
    mapping(string => flight) private flights;                                  // Mapping for storing flights
    address[] private registeredAirlines = new address[](0);
    
    uint constant M = 4;
    uint airlineSize = 0;

    struct insurance {
        address passenger;
        uint amount;
        bool isCredited;
    }
    

    // Restrict data contract callers
    mapping(address => uint256) private authorizedContracts;
    mapping(bytes32 => insurance[]) private insurances;
    mapping(bytes32 => bool) private flightStatuses; // true is late, false is on Time
    mapping(address => uint256) private insurancePayout;
    address[] multiCalls = new address[](0);

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

    /**
    * @dev Modifier that requires function caller to be authorized
    */
    modifier requireIsCallerAuthorized() {
        require(authorizedContracts[msg.sender] == 1, "Caller is not authorized");
        _;
    }

    modifier requireAirlineIsFunded(address _airline) {
        require(isAirlineFunded(_airline) == true, "Airline is not funded");
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
     {
        require(mode != operational, "New mode must be different from existing mode");

        bool isDuplicate = false;

        for(uint i = 0; i < multiCalls.length; i++) {
          if (multiCalls[i] == msg.sender) {
            isDuplicate = true;
            break;
          }
        }

        require(!isDuplicate, "Caller has already called this function.");

        multiCalls.push(msg.sender);

        if (multiCalls.length >= M) {
          operational = mode;
          multiCalls = new address[](0);
        }
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
                            requireIsOperational
                            returns(bool)
    {
        airlines[_airline] = airline({id: registeredAirlines.length, 
                                        isRegistered: true, 
                                        isFunded: false});
        registeredAirlines.push(_airline);
        return true;
    }

    /**
    * @dev For registered airline to submit payment
    *      
    *
    */   
    function fundAirline(address _airline)
                        external
                        requireIsCallerAuthorized
                        requireIsOperational
    {
        airlines[_airline].isFunded = true;
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
                        requireIsOperational
                        returns(bool)
    {
        
        for (uint i=0; i < registeredAirlines.length; i++) {
            if (_airline == registeredAirlines[i]) {
                return true;
            }    
        }
        
        return false;
    }

    function isAirlineFunded
                        (
                            address _airline
                        )
                        public
                        view
                        requireIsOperational
                        returns(bool)
    {
        bool isRegistered = false;
        for (uint i=0; i < registeredAirlines.length; i++) {
            if (_airline == registeredAirlines[i]) {
                isRegistered = true;
            }    
        }
        
        if(isRegistered) {
            return airlines[_airline].isFunded;
        } else {
        return false;
        }
    }

    function getRegisteredAirlines()
        external
        view
        requireIsOperational
        returns(address[] memory)
    {
        return registeredAirlines;
    }


    function registerFlight
    (
        string _flight_num, 
        uint256 _arrival_timestamp, 
        address _airline
    ) 
        external
        requireIsOperational
        requireIsCallerAuthorized
        requireAirlineIsFunded(_airline)
    {
        require(flights[_flight_num].isRegistered = false, "Flight is already registered");
        flights[_flight_num] = flight({
                                flight_num: _flight_num,
                                isRegistered: true,
                                arrival_timestamp: _arrival_timestamp,
                                airline: _airline
                            });
    }

    function isFlightRegistered(string _flight_num) external view returns(bool)
    {
        return (flights[_flight_num].isRegistered == true);
        //return false;
    }

    function isInsured(
        address _airline, 
        string _flight, 
        uint256 timestamp, 
        address _passenger
    )
        external 
        view 
        requireIsOperational
    returns(bool)
    {
        
        for (uint i=0; i < insurances[getFlightKey(_airline, _flight, timestamp)].length; i++) {
            if (_passenger == insurances[getFlightKey(_airline, _flight, timestamp)][i].passenger) {
                return true;
            }    
        }
        return false;
    }


    function getInsuredAmount(
        address _airline, 
        string _flight, 
        uint256 timestamp, 
        address _passenger
    )
        external 
        view 
        requireIsOperational
    returns(uint)
    {
        
        for (uint i=0; i < insurances[getFlightKey(_airline, _flight, timestamp)].length; i++) {
            if (_passenger == insurances[getFlightKey(_airline, _flight, timestamp)][i].passenger) {
                return insurances[getFlightKey(_airline, _flight, timestamp)][i].amount;
            }    
        }
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (
                                address _airline,
                                string _flight,
                                uint256 timestamp,
                                address _passenger,
                                uint _amount                            
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
    {
        insurances[getFlightKey(_airline, _flight, timestamp)].push(insurance({
                                                            passenger: _passenger,
                                                            amount: _amount,
                                                            isCredited: false
                                                        })
        );
    }

    function updateFlightStatus 
                            (
                                address _airline,
                                string _flight,
                                uint256 timestamp,
                                bool isLate
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
    {
        flightStatuses[getFlightKey(_airline, _flight, timestamp)] = isLate;
    }

    function getFlightStatus
                        (   
                                address _airline,
                                string _flight,
                                uint256 timestamp
                        )
                        external
                        view
                        returns(bool)
    {
        return flightStatuses[getFlightKey(_airline, _flight, timestamp)];
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address _airline,
                                    string _flight,
                                    uint256 timestamp
                                )
                                external
                                requireIsOperational
                                requireIsCallerAuthorized
    {
        for (uint i=0; i < insurances[getFlightKey(_airline, _flight, timestamp)].length; i++) {
            insurancePayout[_in.passenger] = 0;
            insurance memory _in = insurances[getFlightKey(_airline, _flight, timestamp)][i];
            insurances[getFlightKey(_airline, _flight, timestamp)][i].isCredited = true;
            insurancePayout[_in.passenger] = _in.amount.mul(3).div(2);
            //insurancePayout[_in.passenger] = SafeMath.add(_in.amount.mul(3).div(2), insurancePayout[_in.passenger]);
        }
    }


    function getInsurancePayout (
                                    address _passenger
                                )
                                external
                                view
                                requireIsOperational
                                returns(uint256)
    {
        return insurancePayout[_passenger];
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                address _passenger
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
    {
        require(insurancePayout[_passenger] > 0 , "No payout available for passenger");
        uint256 payout = insurancePayout[_passenger];
        insurancePayout[_passenger] = 0;

        address(_passenger).transfer(payout);

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
        // address(this).transfer(msg.value); // somehow adding this will fail
    }

    function getFlightKey
                        (
                            address _airline,
                            string memory _flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(_airline, _flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        // fund();
        // address(this).transfer(msg.value);
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

