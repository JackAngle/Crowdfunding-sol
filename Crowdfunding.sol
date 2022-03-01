// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.11;
// This Solidity version has built-in overflow/underflow check

// @notice A crowdfunding smart contract
/// @dev This contract will use Solidity 0.8.x's built-in check to prevent overflow/underflow
/// @dev Functions will use Check-Effect-Interact pattern to prevent Reentrancy
/// @dev Pull over push to prevent Denial-of-Service
contract Crowdfunding  {
    mapping (address => uint) public contributors;
    address public admin;
    uint public numberOfContributors;
    uint public miniumContribution;
    uint public deadline; // block timestamp
    uint public goal;
    uint public raisedAmount;

    // @notice Struct for a request
    /// @dev All Spending Request from admin will use this struct
    struct Request {
        string description;
        address payable recipient;
        uint value;
        bool completed;
        uint256 noOfVoters;
        mapping(address => bool) voters;
    }

    mapping (uint => Request) public requests;
    uint public noOfRequests;

    constructor(uint _goal, uint _deadline) {
        admin = msg.sender;
        deadline = block.timestamp + _deadline;
        miniumContribution = 100 wei;
        goal = _goal;
    }

    /// @dev Function modifier that allow only admin to call the function
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only Admin can call this function");
        _;
    }

    event Contributed(address indexed contributor, uint value);
    // @notice Contribute to this crowdfunding contract
    /// @dev Setting the value to contribute in msg.value
    function contribute() external payable {
        require(block.timestamp < deadline, "Deadline has passed");
        require(msg.value >= miniumContribution);
        if (contributors[msg.sender] == 0) {
            numberOfContributors++;
        }
        contributors[msg.sender] += msg.value;
        raisedAmount += msg.value;
        emit Contributed(msg.sender, msg.value);
    }

    /// @dev Write a default handling for receive() & fallback()
    receive() external payable{}
    fallback() external payable{}
    
    // @notice Get balance information of this contract
    /// @return Balance of this contract
    function getBalance() external view returns(uint){
        return address(this).balance;
    }

    event Refunded(address indexed contributors, uint timestamp);
    // @notice Contributor get refund if the goal is not met after deadline
    /// @return Result of getting refund
    function getRefund() external returns(bool){
        require(block.timestamp > deadline && raisedAmount < goal);
        uint fundLeft = contributors[msg.sender];
        require(fundLeft > miniumContribution, "Contributors has no fund left");
        contributors[msg.sender] = 0;
        numberOfContributors -= 1;
        emit Refunded(msg.sender, block.timestamp);
        (bool result, ) = payable(msg.sender).call{value: fundLeft}("");
        require(result, "getRefund failed");
        return true;
    }

    event CreateRequest(string description, address indexed recipient, uint value);
    // @notice Create a spending request
    /// @dev Create a Request struct object
    /// @param _description The desciption of purpose for creating a request
    /// @param _recipient The address will receive funding of this request
    /// @param _value The value will be used if this request is completed
    function createRequest(string memory _description, address payable _recipient, uint _value) external onlyAdmin {
        Request storage newRequest = requests[noOfRequests];
        noOfRequests++;
        newRequest.description = _description;
        newRequest.recipient = _recipient;
        newRequest.value = _value;
        newRequest.completed = false;
        newRequest.noOfVoters = 0;
        emit CreateRequest(_description, _recipient, _value);
    }

    event Voted(address indexed voter, uint requestNo);
    // @notice Vote "Yes" to a request
    /// @param _requestNo The number of specific created request in the mapping
    function voteRequest(uint _requestNo) external {
        require(contributors[msg.sender] > miniumContribution, "You must be contributor in order to vote!");
        require(_requestNo < noOfRequests, "You are voting an unexisting request!");
        Request storage thisRequest = requests[_requestNo];
        require(!thisRequest.voters[msg.sender], "You have already voted!");
        thisRequest.noOfVoters++;
        thisRequest.voters[msg.sender] = true;
        emit Voted(msg.sender, _requestNo);
    }

    // @notice Get percentage
    /// @dev The goal of this function is to get percentage instead of getting decimal, 
    /// @dev which is not supported by Solidity yet
    /// @param _numerator The numerator of the division
    /// @param _denominator The denominator of the division
    /// @param _precision The precision of the division. For example: 0.8 with precision 2 => 80, with precision 3 => 800
    /// @return The percentage result (uint256) of the division
    function getPercent(uint _numerator, uint _denominator, uint _precision) public pure returns (uint){
        require(_denominator != 0, "Denominator must not be zero");
        return uint(_numerator*(10**_precision)/_denominator);
    }

    event MakePayment(uint requestNo);
    // @notice Make payment for a majority voted request
    /// @param _requestNo The number of specific created request in the mapping
    function makePayment(uint _requestNo) external onlyAdmin{
        require(raisedAmount >= goal);
        require(_requestNo < noOfRequests);

        Request storage thisRequest = requests[_requestNo];
        require(!thisRequest.completed, "The admin already completed this request!");
        require(getPercent(thisRequest.noOfVoters, numberOfContributors, 2) >= 50); // >= 50% voted this request

        thisRequest.completed = true;
        emit MakePayment(_requestNo);

        // address(myAddress).call.value(myValue)(""); is deprecated
        (bool result, ) = payable(thisRequest.recipient).call{value: thisRequest.value}("");
        require(result, "makePayment failed!");
    }
}