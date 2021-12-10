pragma solidity >=0.6.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./ReentrancyGuard.sol";
import "./PolkaWar.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract PolkaWarAirdropDistribution is Ownable, ReentrancyGuard {
    string public name = "PolkaWar: PolkaWarAirdropDistribution";
    using SafeERC20 for IERC20;
    PolkaWar polkaWar;
    address payable private fundOwner;

    uint256 beginDate;
    uint256 endDate;

    struct User {
        uint256 tokenId;
        bool isClaimed;
        bool isValid;
    }

    mapping(address => User) public participants;

    constructor(PolkaWar _polkaWar, address payable _fundOwner) public {
        polkaWar = _polkaWar;
        fundOwner = _fundOwner;
        beginDate = 1627830000; //3PM 1,aug
        endDate = 1630508400; //3PM 1 Sep
    }

    function importData(address[] memory _users, uint256[] memory _tokenids)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _users.length; i++) {
            participants[_users[i]].tokenId = _tokenids[i];
            participants[_users[i]].isClaimed = false;
            participants[_users[i]].isValid = true;
        }
    }

    function changeDate(uint256 _beginDate, uint256 _endDate) public onlyOwner {
        if (_endDate > 0) {
            endDate = _endDate;
        }
        if (_beginDate > 0) {
            beginDate = _beginDate;
        }
    }

    function claimAirdrop() public returns (uint256) {
        require(
            block.timestamp >= beginDate && block.timestamp <= endDate,
            "It's not time to claim yet"
        );

        require(participants[msg.sender].isValid, "Invalid user");
        require(!participants[msg.sender].isClaimed, "Already claimed!");

        polkaWar.transfer(msg.sender, 25 * 1e18);
        participants[msg.sender].isClaimed=true;
        return participants[msg.sender].tokenId;
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
