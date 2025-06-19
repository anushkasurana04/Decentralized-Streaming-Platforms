// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Streaming Platform
 * @dev A smart contract for content creators to monetize streams through micro-payments
 * @author DecentralizedStreamingPlatforms Team
 */
contract Project {
    // State variables
    address public owner;
    uint256 public platformFeePercentage = 5; // 5% platform fee
    uint256 public constant SECONDS_IN_HOUR = 3600;
    
    // Structs
    struct Creator {
        address payable wallet;
        string name;
        uint256 pricePerSecond; // Price in wei per second of viewing
        uint256 totalEarnings;
        bool isActive;
        uint256 subscriberCount;
    }
    
    struct Viewer {
        uint256 balance; // Prepaid balance for streaming
        mapping(address => uint256) watchTime; // Total watch time per creator
        mapping(address => uint256) lastWatchStart; // Timestamp when started watching
    }
    
    struct Stream {
        address creator;
        string title;
        string description;
        uint256 startTime;
        bool isLive;
        uint256 viewerCount;
    }
    
    // Mappings
    mapping(address => Creator) public creators;
    mapping(address => Viewer) public viewers;
    mapping(uint256 => Stream) public streams;
    mapping(address => bool) public registeredCreators;
    
    // Arrays for iteration
    address[] public creatorList;
    uint256[] public activeStreams;
    uint256 public streamCounter;
    
    // Events
    event CreatorRegistered(address indexed creator, string name, uint256 pricePerSecond);
    event StreamStarted(uint256 indexed streamId, address indexed creator, string title);
    event StreamEnded(uint256 indexed streamId, address indexed creator);
    event ViewerDeposited(address indexed viewer, uint256 amount);
    event PaymentProcessed(address indexed viewer, address indexed creator, uint256 amount, uint256 watchTime);
    event CreatorPaidOut(address indexed creator, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyRegisteredCreator() {
        require(registeredCreators[msg.sender], "Only registered creators can call this function");
        _;
    }
    
    modifier onlyActiveCreator() {
        require(creators[msg.sender].isActive, "Creator must be active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Core Function 1: Register as a content creator
     * @param _name Creator's display name
     * @param _pricePerSecond Price in wei that viewers pay per second of viewing
     */
    function registerCreator(string calldata _name, uint256 _pricePerSecond) external {
        require(!registeredCreators[msg.sender], "Creator already registered");
        require(_pricePerSecond > 0, "Price per second must be greater than 0");
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        creators[msg.sender] = Creator({
            wallet: payable(msg.sender),
            name: _name,
            pricePerSecond: _pricePerSecond,
            totalEarnings: 0,
            isActive: true,
            subscriberCount: 0
        });
        
        registeredCreators[msg.sender] = true;
        creatorList.push(msg.sender);
        
        emit CreatorRegistered(msg.sender, _name, _pricePerSecond);
    }
    
    /**
     * @dev Core Function 2: Start streaming content
     * @param _title Stream title
     * @param _description Stream description
     */
    function startStream(string calldata _title, string calldata _description) external onlyRegisteredCreator onlyActiveCreator {
        require(bytes(_title).length > 0, "Title cannot be empty");
        
        streamCounter++;
        streams[streamCounter] = Stream({
            creator: msg.sender,
            title: _title,
            description: _description,
            startTime: block.timestamp,
            isLive: true,
            viewerCount: 0
        });
        
        activeStreams.push(streamCounter);
        
        emit StreamStarted(streamCounter, msg.sender, _title);
    }
    
    /**
     * @dev Core Function 3: Process viewer payments based on watch time
     * @param _creator Address of the creator being watched
     * @param _watchTimeSeconds Number of seconds watched
     */
    function processPayment(address _creator, uint256 _watchTimeSeconds) external payable {
        require(registeredCreators[_creator], "Creator not registered");
        require(creators[_creator].isActive, "Creator is not active");
        require(_watchTimeSeconds > 0, "Watch time must be greater than 0");
        
        Creator storage creator = creators[_creator];
        Viewer storage viewer = viewers[msg.sender];
        
        uint256 totalCost = creator.pricePerSecond * _watchTimeSeconds;
        uint256 platformFee = (totalCost * platformFeePercentage) / 100;
        uint256 creatorEarnings = totalCost - platformFee;
        
        // Check if viewer has enough balance (from deposits + current payment)
        uint256 availableBalance = viewer.balance + msg.value;
        require(availableBalance >= totalCost, "Insufficient balance for payment");
        
        // Update viewer balance
        if (msg.value > 0) {
            viewer.balance += msg.value;
            emit ViewerDeposited(msg.sender, msg.value);
        }
        
        // Deduct payment from viewer balance
        viewer.balance -= totalCost;
        
        // Update watch time
        viewer.watchTime[_creator] += _watchTimeSeconds;
        
        // Update creator earnings
        creator.totalEarnings += creatorEarnings;
        
        // Transfer payment to creator
        creator.wallet.transfer(creatorEarnings);
        
        emit PaymentProcessed(msg.sender, _creator, totalCost, _watchTimeSeconds);
        emit CreatorPaidOut(_creator, creatorEarnings);
    }
    
    // Additional utility functions
    
    /**
     * @dev Deposit funds for future streaming payments
     */
    function depositFunds() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        viewers[msg.sender].balance += msg.value;
        emit ViewerDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev End a live stream
     * @param _streamId ID of the stream to end
     */
    function endStream(uint256 _streamId) external {
        require(streams[_streamId].creator == msg.sender, "Only stream creator can end stream");
        require(streams[_streamId].isLive, "Stream is not live");
        
        streams[_streamId].isLive = false;
        
        // Remove from active streams array
        for (uint i = 0; i < activeStreams.length; i++) {
            if (activeStreams[i] == _streamId) {
                activeStreams[i] = activeStreams[activeStreams.length - 1];
                activeStreams.pop();
                break;
            }
        }
        
        emit StreamEnded(_streamId, msg.sender);
    }
    
    /**
     * @dev Get viewer's current balance
     * @param _viewer Address of the viewer
     * @return Current balance in wei
     */
    function getViewerBalance(address _viewer) external view returns (uint256) {
        return viewers[_viewer].balance;
    }
    
    /**
     * @dev Get total watch time for a viewer with specific creator
     * @param _viewer Address of the viewer
     * @param _creator Address of the creator
     * @return Total watch time in seconds
     */
    function getWatchTime(address _viewer, address _creator) external view returns (uint256) {
        return viewers[_viewer].watchTime[_creator];
    }
    
    /**
     * @dev Get list of all active streams
     * @return Array of active stream IDs
     */
    function getActiveStreams() external view returns (uint256[] memory) {
        return activeStreams;
    }
    
    /**
     * @dev Get creator information
     * @param _creator Address of the creator
     * @return Creator struct information
     */
    function getCreatorInfo(address _creator) external view returns (
        string memory name,
        uint256 pricePerSecond,
        uint256 totalEarnings,
        bool isActive,
        uint256 subscriberCount
    ) {
        Creator memory creator = creators[_creator];
        return (
            creator.name,
            creator.pricePerSecond,
            creator.totalEarnings,
            creator.isActive,
            creator.subscriberCount
        );
    }
    
    /**
     * @dev Update platform fee (only owner)
     * @param _newFeePercentage New platform fee percentage
     */
    function updatePlatformFee(uint256 _newFeePercentage) external onlyOwner {
        require(_newFeePercentage <= 10, "Platform fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
    }
    
    /**
     * @dev Withdraw platform fees (only owner)
     */
    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner).transfer(balance);
    }
    
    /**
     * @dev Emergency pause creator (only owner)
     * @param _creator Address of creator to pause
     */
    function pauseCreator(address _creator) external onlyOwner {
        require(registeredCreators[_creator], "Creator not registered");
        creators[_creator].isActive = false;
    }
    
    /**
     * @dev Get total number of registered creators
     * @return Number of registered creators
     */
    function getTotalCreators() external view returns (uint256) {
        return creatorList.length;
    }
}
