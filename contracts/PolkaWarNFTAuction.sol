pragma solidity >=0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./ReentrancyGuard.sol";
import "./PolkaWarItemSystem.sol";
import "./PolkaWar.sol";
import "./CorgibStaking.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract PolkaWarNFTAuction is Ownable, ReentrancyGuard {
    string public name = "PolkaWar: NFT Auction";
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    PolkaWarItemSystem itemSystem;
    PolkaWar polkaWar;
    CorgibStaking staking;

    address payable private fundOwner;

    struct Program {
        string urlHash;
        uint256 startPrice;
        bool isActive;
        uint256 beginDate;
        uint256 endDate;
        uint256 latestPrice;
        address payable latestUser;
        uint256 minPWARHolding;
        bool isClaimed;
        int256 comboRewards;
        uint256 tokenId;
        bool isOpened;
    }
    struct Participant {
        uint256 bidTime;
        uint256 bidPrice;
    }

    struct Reward {
        uint256 amountBNB;
        uint256 amountPWAR;
        uint256 itemIndex;
    }

    //list airdrop item

    Program[] public programs;
    Reward[] public rewards;
    string[] public nftItems;

    mapping(uint256 => mapping(address => Participant)) internal participants;
    address[] internal arrParticipants;

    event _bid(uint256 _pid, uint256 _bidPrice, address _user);

    event _cancelBid(address user, uint256 _pid);

    event _claim(address user, uint256 _pid, uint256 _tokenid);

    event _open(address user, uint256 _pid, int256 _combo, uint256 _nftTokenId);

    constructor(
        PolkaWarItemSystem _itemSystem,
        PolkaWar _polkaWar,
        CorgibStaking _staking,
        address payable _fundOwner
    ) public {
        itemSystem = _itemSystem;
        polkaWar = _polkaWar;
        fundOwner = _fundOwner;
        staking = _staking;
    }

    function initProgram(
        string memory _urlHash,
        uint256 _startPrice,
        uint256 _beginDate,
        uint256 _endDate
    ) public onlyOwner {
        programs.push(
            Program({
                urlHash: _urlHash,
                startPrice: _startPrice,
                isActive: true,
                beginDate: _beginDate,
                endDate: _endDate,
                latestPrice: _startPrice,
                latestUser: fundOwner,
                minPWARHolding: 2000000000000000000000,
                isClaimed: false,
                comboRewards: -1,
                tokenId: 0,
                isOpened: false
            })
        );
    }

    function updateProgram(
        uint256 _pid,
        uint256 _startPrice,
        uint256 _beginDate,
        uint256 _endDate,
        uint256 _minimumHolding
    ) public onlyOwner {
        Program storage programInfo = programs[_pid];
        if (_startPrice > 0) {
            programInfo.startPrice = _startPrice;
        }
        if (_beginDate > 0) {
            programInfo.beginDate = _beginDate;
        }
        if (_endDate > 0) {
            programInfo.endDate = _endDate;
        }
        if (_minimumHolding > 0) {
            programInfo.minPWARHolding = _minimumHolding;
        }
    }

    function initRewards(Reward memory _rewards) public onlyOwner {
        rewards.push(_rewards);
    }

    function initNFTItems(string[] memory _items) public onlyOwner {
        for (uint256 i = 0; i < _items.length; i++) {
            nftItems.push(_items[i]);
        }
    }

    function bid(
        uint256 _pid,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes32 messageHash
    ) public payable nonReentrant {
        require(
            owner() == ecrecover(messageHash, v, r, s),
            "Owner should sign bid info"
        );
        Program storage programInfo = programs[_pid];
        Participant storage user = participants[_pid][msg.sender];
        require(
            programInfo.isActive &&
                block.timestamp >= programInfo.beginDate &&
                block.timestamp < programInfo.endDate,
            "Invalid time"
        );

        uint256 numberHoldingOrStaking = getNumberHoldingOrStaking(msg.sender);
        require(
            numberHoldingOrStaking >= programInfo.minPWARHolding,
            "Insufficient number of PWAR staking or holding"
        );
        require(msg.value > programInfo.latestPrice, "Invalid price");

        //-----update user bid info
        user.bidTime = block.timestamp;
        user.bidPrice = msg.value;

        //-----refund previous user
        //previous user infomation
        Participant storage preUser = participants[_pid][
            programInfo.latestUser
        ];
        if (programInfo.latestUser != fundOwner) {
            programInfo.latestUser.transfer(preUser.bidPrice);
        }

        //-----updade auction info
        programInfo.latestPrice = msg.value;
        programInfo.latestUser = msg.sender;

        arrParticipants.push(msg.sender);

        emit _bid(_pid, msg.value, msg.sender);
    }

    function claim(uint256 _pid) public returns (uint256) {
        Program storage programInfo = programs[_pid];
        require(
            programInfo.isActive && block.timestamp > programInfo.endDate,
            "Invalid time"
        );

        require(!programInfo.isClaimed, "Already claimed!");

        require(
            programInfo.latestUser == msg.sender,
            "You are not the winner!"
        );
        uint256 tokenId = itemSystem.createItem(
            msg.sender,
            programInfo.urlHash
        );

        programInfo.isClaimed = true;
        programInfo.tokenId = tokenId;

        emit _claim(msg.sender, _pid, tokenId);

        return tokenId;
    }

    function open(uint256 _pid) public returns (int256, uint256) {
        Program storage programInfo = programs[_pid];

        require(
            programInfo.tokenId > 0 && programInfo.comboRewards >= 0,
            "Not available"
        );

        require(
            programInfo.isActive && block.timestamp > programInfo.endDate,
            "Invalid time"
        );

        require(!programInfo.isOpened, "Already opened!");

        require(
            programInfo.latestUser == msg.sender,
            "You are not the winner!"
        );

        //logic and rewards
        uint256 rewardIndex = uint256(programInfo.comboRewards);
        Reward storage rewardOpen = rewards[rewardIndex];

        polkaWar.transfer(msg.sender, rewardOpen.amountPWAR);
        msg.sender.transfer(rewardOpen.amountBNB);
        uint256 nftTokenId = itemSystem.createItem(
            msg.sender,
            nftItems[rewardOpen.itemIndex]
        );

        programInfo.isOpened = true;
        emit _open(msg.sender, _pid, programInfo.comboRewards, nftTokenId);

        return (programInfo.comboRewards, nftTokenId);
    }

    function withdrawToken(IERC20 token) public onlyOwner {
        token.transfer(owner(), token.balanceOf(address(this)));
    }

    function withdrawPoolFund() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "not enough fund");
        fundOwner.transfer(balance);
    }

    function getNumberHoldingOrStaking(address user)
        public
        view
        returns (uint256)
    {
        uint256 amountHolding = polkaWar.balanceOf(user);
        (
            uint256 amount,
            uint256 rewardDebt,
            uint256 rewardClaimed,
            uint256 lastBlock,
            uint256 beginTime,
            uint256 endTime
        ) = getUserStakingData(user, 1);
        return amountHolding.add(amount);
    }

    function getUserStakingData(address user, uint256 poolId)
        public
        view
        returns (
            uint256 amount,
            uint256 rewardDebt,
            uint256 rewardClaimed,
            uint256 lastBlock,
            uint256 beginTime,
            uint256 endTime
        )
    {
        return (staking.userInfo(poolId, user));
    }

    function isUserBid(address _user, uint256 _pid) public view returns (bool) {
        Participant storage user = participants[_pid][_user];
        Program storage programInfo = programs[_pid];

        if (
            user.bidPrice > 0 &&
            user.bidTime >= programInfo.beginDate &&
            user.bidTime < programInfo.endDate
        ) {
            return true;
        }
        return false;
    }

    function getUserInfo(address _user, uint256 _pid)
        public
        view
        returns (uint256, uint256)
    {
        Participant storage user = participants[_pid][_user];
        Program storage programInfo = programs[_pid];
        return (user.bidTime, user.bidPrice);
    }

    function getNumberParticipants() public view returns (uint256) {
        return arrParticipants.length;
    }

    function setRewards(uint256 _pid, int256 _combo) public onlyOwner {
        Program storage programInfo = programs[_pid];
        programInfo.comboRewards = _combo;
    }

    receive() external payable {}
}
