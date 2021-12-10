pragma solidity >=0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./ReentrancyGuard.sol";
import "./PolkaWarItemSystem.sol";
import "./PolkaWar.sol";
import "./CorgibStaking.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract PolkaWarClaimXP is Ownable, ReentrancyGuard {
    string public name = "PolkaWar: ClaimXP";
    using SafeMath for uint256;

    PolkaWar polkaWar;
    CorgibStaking staking;
    address payable private fundOwner;
    address payable private marketingFund;

    uint256 beginDate;
    uint256 endDate;
    uint256 public minimumHolding;
    uint256 public baseAmount;
    uint256 public baseXP;
    uint256 public maxClaimNumber;

    uint256 public devPercent;
    uint256 public marketingPercent;
    uint256 public burnPercent;

    //list airdrop item
    struct User {
        uint256 numberClaimed;
        uint256 totalXPClaimed;
        uint256 lastClaimed;
        uint256 characterLevel;
    }

    mapping(address => User) public participants;
    address[] public arrParticipants; //user-tokenid

    event claimXPEvent(
        address _user,
        uint256 _totalPWAR,
        uint256 _numberClaim,
        uint256 _timeStamp
    );

    constructor(
        PolkaWar _polkaWar,
        CorgibStaking _staking,
        address payable _fundOwner,
        address payable _marketingFund
    ) public {
        polkaWar = _polkaWar;
        staking = _staking;
        fundOwner = _fundOwner;
        marketingFund = _marketingFund;
        minimumHolding = 2000 * 1e18;
        baseAmount = 10 * 1e18;
        beginDate = 1629813600;
        endDate = 1635724800;
        maxClaimNumber = 60;
        baseXP = 10;

        devPercent = 10;
        marketingPercent = 50;
        burnPercent = 40;
    }

    function changeConstant(
        uint256 _beginDate,
        uint256 _endDate,
        uint256 _minimumHolding,
        uint256 _baseAmount,
        uint256 _maxClaimNumber,
        uint256 _baseXP,
        uint256 _devPercent,
        uint256 _marketingPercent,
        uint256 _burnPercent
    ) public onlyOwner {
        if (_beginDate > 0) {
            beginDate = _beginDate;
        }
        if (_endDate > 0) {
            endDate = _endDate;
        }

        if (_minimumHolding > 0) {
            minimumHolding = _minimumHolding;
        }
        if (_baseAmount > 0) {
            baseAmount = _baseAmount;
        }
        if (_maxClaimNumber > 0) {
            maxClaimNumber = _maxClaimNumber;
        }
        if (_baseXP > 0) {
            baseXP = _baseXP;
        }
        if (_devPercent > 0) {
            devPercent = _devPercent;
        }
        if (_burnPercent > 0) {
            burnPercent = _burnPercent;
        }
        if (_marketingPercent > 0) {
            marketingPercent = _marketingPercent;
        }
    }

    function claimXP(uint256 characterLevel) public nonReentrant {
        User storage user = participants[msg.sender];

        require(
            block.timestamp >= beginDate && block.timestamp <= endDate,
            "invalid time"
        );
        //check numberclaimperday
        require(getCycleTimeClaim(msg.sender) > 0, "only claim 1 time per day");

        require(user.numberClaimed < maxClaimNumber, "reach maximum claim");
        uint256 numberHoldingOrStaking = getNumberHoldingOrStaking(msg.sender);
        require(
            numberHoldingOrStaking >= minimumHolding,
            "Insufficient number of PWAR staking or holding"
        );

        user.numberClaimed = user.numberClaimed.add(1);
        uint256 pwarRequire = baseAmount.mul(user.numberClaimed);

        polkaWar.transferFrom(
            address(msg.sender),
            fundOwner,
            pwarRequire.mul(devPercent).div(100)
        );
        polkaWar.transferFrom(
            address(msg.sender),
            marketingFund,
            pwarRequire.mul(marketingPercent).div(100)
        );
        polkaWar.burnFrom(
            address(msg.sender),
            pwarRequire.mul(burnPercent).div(100)
        );

        user.lastClaimed = block.timestamp;
        user.characterLevel = characterLevel;
        user.totalXPClaimed = user.totalXPClaimed.add(
            user.numberClaimed * baseXP
        );
        emit claimXPEvent(
            msg.sender,
            pwarRequire,
            user.numberClaimed,
            block.timestamp
        );
    }

    function getCycleTimeClaim(address _user) public view returns (uint256) {
        User storage user = participants[msg.sender];
        return (block.timestamp.sub(user.lastClaimed)).div(23 * 3600);
    }

    function getNumberClaim(address user) public view returns (uint256) {
        return participants[msg.sender].numberClaimed;
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
