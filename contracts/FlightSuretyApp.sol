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

    uint constant REGISTER_AIRLINE_MULTICALL_LIMIT = 4;
    uint constant REGISTER_AIRLINE_MULTICALL_PERCENTAGE = 50;

    uint constant MAX_INSURANCE = 1 ether;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;
    mapping(address => address[]) private airline_multicall;    
    FlightSuretyData flightSuretyData;

    uint256 registrationFee = 10 ether;
 
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
        require(flightSuretyData.isOperational(), "Contract is currently not operational");  
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
        require(msg.value >= _price, "Payment is not enough"); 
        _;
    }
  
    // Define a modifier that checks the price and refunds the remaining balance
    modifier checkValue(address newAirline) {
        _;
        uint _price = registrationFee;
        uint amountToReturn = msg.value - _price;
        newAirline.transfer(amountToReturn);
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
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public view
                            returns(bool) 
    {
        return flightSuretyData.isOperational();  // Modify to call data contract's status
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
                                address airline
                            )
                            external
                            requireIsOperational
                            returns(bool)
    {
        address[] memory registeredAirlines = flightSuretyData.getRegisteredAirlines();
        // require(flightSuretyData.airlines().isAdmin, "Caller is not an admin");
        if (registeredAirlines.length < REGISTER_AIRLINE_MULTICALL_LIMIT) {
            flightSuretyData.registerAirline(airline);
            emit AirlineRegistered(airline);
            return true;
        } else {
            
            bool isDuplicate = false;
            for (uint i=0; i < airline_multicall[airline].length; i++) {
                if (airline_multicall[airline][i] == msg.sender) {
                    isDuplicate = true;
                    break;
                }    
            }

            require(!isDuplicate, "Caller has already voted");
            airline_multicall[airline].push(msg.sender);
            if (airline_multicall[airline].length >= registeredAirlines.length * REGISTER_AIRLINE_MULTICALL_PERCENTAGE / 100 ) {
                    flightSuretyData.registerAirline(airline);
                    emit AirlineRegistered(airline);
                    return true;
            } else {
                return false;
            }
            
        }
    }

    function fundAirline
                        (
                        )
                        external
                        requireIsOperational
                        payable
                        paidEnough(registrationFee)
                        checkValue(msg.sender) 
                        returns(bool)
    {
        require(flightSuretyData.isAirlineFunded(msg.sender) == false, "Airline is already funded");
        address(flightSuretyData).transfer(registrationFee);
        // flightSuretyData.transfer(registrationFee);
        flightSuretyData.fundAirline(msg.sender);
        emit AirlineFunded(msg.sender);
        return true;
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                                (
                                    string flight_num,
                                    uint256 arrival_timestamp
                                )
                                external
                                requireIsOperational

    {
        flightSuretyData.registerFlight(flight_num, arrival_timestamp, msg.sender);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
    {
        // update airline flight status
        bool isLate = false;
        if(statusCode > 10) {
            isLate = true; // late
        }

        flightSuretyData.updateFlightStatus(airline, flight, timestamp, isLate);
        emit FlightStatusUpdated(airline, flight, timestamp, isLate);

        if (isLate) {
            flightSuretyData.creditInsurees(airline, flight, timestamp);
            emit InsuranceCredited(airline, flight, timestamp);
        }
        // call pay functions
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp                            
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 


    function buyInsurance
                        (
                                address _airline,
                                string _flight,
                                uint256 timestamp                          
                        )
                        external
                        requireIsOperational
                        payable
    {
        require(msg.value > 0, "Need to pay more than 0 to buy insurance");
        require(msg.value <= MAX_INSURANCE, "Cannot pay more than maximum");
        require(flightSuretyData.isFlightRegistered(_flight), "Flight does not exist");
        require(!flightSuretyData.isInsured(_airline, _flight, timestamp, msg.sender), "Passenger is already insured");
        
        address(flightSuretyData).transfer(msg.value);
        flightSuretyData.buy(_airline, _flight, timestamp, msg.sender, msg.value);
        emit InsuranceBought(_airline, _flight, timestamp, msg.sender, msg.value);
    }

    function withdraw () external requireIsOperational {
        flightSuretyData.pay(msg.sender);
        emit InsuranceWithdrew(msg.sender);
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

    // Event fired each time an oracle submits a response

    event AirlineRegistered(address addr);
    event AirlineFunded(address addr);
    event InsuranceWithdrew(address addr);

    event InsuranceBought(address airline, string flight, uint256 timestamp, address passenger, uint amount);
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);
    event FlightStatusUpdated(address airline, string flight, uint256 timestamp, bool isLate);
    event InsuranceCredited(address airline, string flight, uint256 timestamp);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

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
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {

        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");

        // emit OracleReport(airline, flight, timestamp, statusCode);
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getRegistrationFee() public pure returns(uint256) {
        return REGISTRATION_FEE;
    }

    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
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


contract FlightSuretyData {
    function registerAirline(address Airline) external payable returns(bool);
    function isAirlineRegistered(address airline) external view returns(bool);
    function isOperational() public view returns(bool);
    function getRegisteredAirlines() external view returns(address[] memory);
    function setOperatingStatus(bool mode) external;
    function fundAirline(address _airline) external;
    function isAirlineFunded(address _airline) public view returns(bool);
    function fund() public payable;
    function registerFlight(string _flight_num, uint256 _arrival_timestamp, address _airline) external;
    function isFlightRegistered(string _flight_num) external view returns(bool);
    function isInsured(address _airline, string _flight, uint256 timestamp, address _passenger) external view returns(bool);
    function buy(address _airline, string _flight, uint256 timestamp, address _passenger, uint _amount) external;
    function updateFlightStatus(address _airline, string _flight, uint256 timestamp, bool isLate) external;
    function creditInsurees(address _airline, string _flight, uint256 timestamp) external;
    function pay(address _airline) external;
}


//TO DO 1: add events
//TO DO 2: Why canot add numbers
//TO DO 3: Why withdrawal gas is not correct/

