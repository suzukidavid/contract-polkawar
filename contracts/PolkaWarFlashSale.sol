pragma solidity >=0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./ReentrancyGuard.sol";
import "./PolkaWarItemSystem.sol";
import "./PolkaWar.sol";
import "./CorgibStaking.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract PolkaWarFlashSale is Ownable, ReentrancyGuard {
    string public name = "PolkaWar: NFT FlashSale";
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    PolkaWarItemSystem itemSystem;
    PolkaWar polkaWar;
    CorgibStaking staking;
    address payable private fundOwner;

    uint256 beginDate;
    uint256 endDate;
    uint256 public maximumSoldCount;
    uint256 public maximumPerItem;
    uint256 price;
    uint256 public minimumHolding;
    uint256 buybackPrice;
    uint256 resellBeginDate;
    uint256 resellEndDate;

    struct Item {
        uint256 countSlot;
        bool isValid;
    }

    //list airdrop item

    mapping(address => uint256) internal participants; //user-tokenid (1user can only buy 1 NFT in flashsale)
    address[] internal arrParticipants; //user-tokenid

    mapping(uint256 => Item) public listItem;

    event purchaseEvent(address user, uint256 tokenId, string itemInfoHash);

    event resellEvent(address user, uint256 tokenId);

    constructor(
        PolkaWarItemSystem _itemSystem,
        PolkaWar _polkaWar,
        CorgibStaking _staking,
        address payable _fundOwner
    ) public {
        itemSystem = _itemSystem;
        polkaWar = _polkaWar;
        staking = _staking;
        fundOwner = _fundOwner;
        maximumSoldCount = 200;
        maximumPerItem = 20;

        beginDate = 1636207200;
        endDate = 1636210800;
        resellBeginDate = 1636214400;
        resellEndDate = 1636218000;

        price = 1000000000000000000;
        minimumHolding = 2000000000000000000000;
        buybackPrice = 1100000000000000000;
    }

    function initItem(uint256[] memory _lstItem) public onlyOwner {
        for (uint256 i = 0; i < _lstItem.length; i++) {
            listItem[_lstItem[i]].isValid = true;
            listItem[_lstItem[i]].countSlot = 0;
        }
    }

    function changeConstant(
        uint256 _beginDate,
        uint256 _endDate,
        uint256 _maximumSoldCount,
        uint256 _maximumPerItem,
        uint256 _price,
        uint256 _buybackprice,
        uint256 _resellBeginDate,
        uint256 _resellEndDate,
        uint256 _minimumHolding
    ) public onlyOwner {
        if (_beginDate > 0) {
            beginDate = _beginDate;
        }
        if (_endDate > 0) {
            endDate = _endDate;
        }
        if (_maximumSoldCount > 0) {
            maximumSoldCount = _maximumSoldCount;
        }
        if (_price > 0) {
            price = _price;
        }
        if (_buybackprice > 0) {
            buybackPrice = _buybackprice;
        }
        if (_resellBeginDate > 0) {
            resellBeginDate = _resellBeginDate;
        }
        if (_resellEndDate > 0) {
            resellEndDate = _resellEndDate;
        }
        if (_maximumPerItem > 0) {
            maximumPerItem = _maximumPerItem;
        }
        if (_minimumHolding > 0) {
            minimumHolding = _minimumHolding;
        }
    }

    function purchaseItem(
        uint256 itemId,
        string memory itemInfoHash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes32 messageHash
    ) public payable nonReentrant returns (uint256) {
        require(
            owner() == ecrecover(messageHash, v, r, s),
            "owner should sign purchase info"
        );

        require(
            block.timestamp >= beginDate && block.timestamp <= endDate,
            "flashsale finished"
        );
        require(
            getTotalParticipants() <= maximumSoldCount,
            "reached maximum slots"
        );
        require(listItem[itemId].isValid, "not valid item");
        require(
            listItem[itemId].countSlot < maximumPerItem,
            "This item is sold out"
        );
        require(msg.value >= price, "invalid price");
        require(!isPurchased(msg.sender), "already purchased");

        uint256 numberHoldingOrStaking = getNumberHoldingOrStaking(msg.sender);
        require(
            numberHoldingOrStaking >= minimumHolding,
            "Insufficient number of PWAR staking or holding"
        );

        uint256 tokenId = itemSystem.createItem(msg.sender, itemInfoHash);
        participants[msg.sender] = tokenId;
        arrParticipants.push(msg.sender);
        listItem[itemId].countSlot = listItem[itemId].countSlot.add(1);

        emit purchaseEvent(msg.sender, tokenId, itemInfoHash);

        return tokenId;
    }

    //resell flashsale item for system
    function resellItemForSystem() public nonReentrant {
        address payable user = msg.sender;

        require(
            block.timestamp >= resellBeginDate,
            "buyback program not started yet"
        );
        require(block.timestamp <= resellEndDate, "buyback program ended");
        require(address(this).balance >= buybackPrice, "not enough fund");

        uint256 ownTokenId = participants[user];
        require(ownTokenId > 0, "invalid item");

        itemSystem.safeTransferFrom(user, owner(), ownTokenId);

        user.transfer(buybackPrice);

        emit resellEvent(user, ownTokenId);
    }

    function isPurchased(address user) public view returns (bool) {
        if (participants[user] > 0) return true;
        return false;
    }

    function getTotalParticipants() public view returns (uint256) {
        return arrParticipants.length;
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

    function withdrawToken(IERC20 token) public onlyOwner {
        token.transfer(owner(), token.balanceOf(address(this)));
    }

    function withdrawPoolFund() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "not enough fund");
        fundOwner.transfer(balance);
    }

    receive() external payable {}
}
