pragma solidity >=0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./PolkaWar.sol";

contract TokenRelease {
    using SafeMath for uint256;
    PolkaWar private _polkawar;
    event TokensReleased(address beneficiary, uint256 amount);
    address payable private owner;
    // beneficiary of tokens after they are released
    string public name = "PolkaWar: Token Vesting";

    struct Vesting {
        string Name;
        address Beneficiary;
        uint256 Cliff;
        uint256 Start;
        uint256 AmountReleaseInOne;
        uint256 MaxRelease;
        bool IsExist;
    }
    mapping(address => Vesting) private _vestingList;

    constructor(
        PolkaWar polkaWar,
        address team,
        address marketing,
        address eco,
        address privateFund
    ) public {
        _polkawar = polkaWar;
        _vestingList[team].Name = "Team Fund";
        _vestingList[team].Beneficiary = team;
        _vestingList[team].Cliff = 15778458;//6 month
        _vestingList[team].Start = 1625097600; //1/7/2021
        _vestingList[team].AmountReleaseInOne = 5000000*1e18;
        _vestingList[team].MaxRelease = 20000000*1e18;
        _vestingList[team].IsExist = true;

        _vestingList[marketing].Name = "Marketing Fund";
        _vestingList[marketing].Beneficiary = marketing;
        _vestingList[marketing].Cliff = 2629743;//1 month
        _vestingList[marketing].Start = 1635724800; //1/11/2021
        _vestingList[marketing]
            .AmountReleaseInOne = 1000000*1e18;
        _vestingList[marketing].MaxRelease = 20000000*1e18;
        _vestingList[marketing].IsExist = true;

        _vestingList[eco].Name = "Ecosystem Fund";
        _vestingList[eco].Beneficiary = eco;
        _vestingList[eco].Cliff =  2629743;//1 month
        _vestingList[eco].Start = 1635724800; //1/11/2021
        _vestingList[eco].AmountReleaseInOne = 1000000*1e18;
        _vestingList[eco].MaxRelease =  35000000*1e18;
        _vestingList[eco].IsExist = true;

        _vestingList[privateFund].Name = "Private Fund";
        _vestingList[privateFund].Beneficiary = privateFund;
        _vestingList[privateFund].Cliff =  2629743;//1 month
        _vestingList[privateFund].Start = 1640995200; //1/1/2022
        _vestingList[privateFund].AmountReleaseInOne = 1000000*1e18;
        _vestingList[privateFund].MaxRelease =  20000000*1e18;
        _vestingList[privateFund].IsExist = true;

        owner = msg.sender;
    }

    function depositETHtoContract() public payable {}

    function addLockingFund(
        string memory name,
        address beneficiary,
        uint256 cliff,
        uint256 start,
        uint256 amountReleaseInOne,
        uint256 maxRelease
    ) public {
        require(msg.sender == owner, "only owner can addLockingFund");
        _vestingList[beneficiary].Name = name;
        _vestingList[beneficiary].Beneficiary = beneficiary;
        _vestingList[beneficiary].Cliff = cliff;
        _vestingList[beneficiary].Start = start;
        _vestingList[beneficiary].AmountReleaseInOne = amountReleaseInOne;
        _vestingList[beneficiary].MaxRelease = maxRelease;
        _vestingList[beneficiary].IsExist = true;
    }

    function beneficiary(address acc) public view returns (address) {
        return _vestingList[acc].Beneficiary;
    }

    function cliff(address acc) public view returns (uint256) {
        return _vestingList[acc].Cliff;
    }

    function start(address acc) public view returns (uint256) {
        return _vestingList[acc].Start;
    }

    function amountReleaseInOne(address acc) public view returns (uint256) {
        return _vestingList[acc].AmountReleaseInOne;
    }

    function getNumberCycle(address acc) public view returns (uint256) {
        return
            (block.timestamp.sub(_vestingList[acc].Start)).div(
                _vestingList[acc].Cliff
            );
    }

    function getRemainBalance() public view returns (uint256) {
        return _polkawar.balanceOf(address(this));
    }

    function getRemainUnlockAmount(address acc) public view returns (uint256) {
        return _vestingList[acc].MaxRelease;
    }

    function isValidBeneficiary(address _wallet) public view returns (bool) {
        return _vestingList[_wallet].IsExist;
    }

    function release(address acc) public {
        require(acc != address(0), "TokenRelease: address 0 not allow");
        require(
            isValidBeneficiary(acc),
            "TokenRelease: invalid release address"
        );

        require(
            _vestingList[acc].MaxRelease > 0,
            "TokenRelease: no more token to release"
        );

        uint256 unreleased = _releasableAmount(acc);

        require(unreleased > 0, "TokenRelease: no tokens are due");

        _polkawar.transfer(_vestingList[acc].Beneficiary, unreleased);
        _vestingList[acc].MaxRelease -= unreleased;

        emit TokensReleased(_vestingList[acc].Beneficiary, unreleased);
    }

    function _releasableAmount(address acc) private returns (uint256) {
        uint256 currentBalance = _polkawar.balanceOf(address(this));
        if (currentBalance <= 0) return 0;
        uint256 amountRelease = 0;
        //require(_start.add(_cliff) < block.timestamp, "not that time");
        if (
            _vestingList[acc].Start.add(_vestingList[acc].Cliff) >
            block.timestamp
        ) {
            //not on time

            amountRelease = 0;
        } else {
            uint256 numberCycle = getNumberCycle(acc);
            if (numberCycle > 0) {
                amountRelease =
                    numberCycle *
                    _vestingList[acc].AmountReleaseInOne;
            } else {
                amountRelease = 0;
            }

            _vestingList[acc].Start = block.timestamp; //update start
        }
        return amountRelease;
    }

    function withdrawEtherFund() public {
        require(msg.sender == owner, "only owner can withdraw");
        uint256 balance = address(this).balance;
        require(balance > 0, "not enough fund");
        owner.transfer(balance);
    }
}
