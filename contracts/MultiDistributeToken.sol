pragma solidity >=0.6.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "@openzeppelin/contracts/ownership/Ownable.sol";


contract MultiDistributeToken is Ownable {
    string public name = "PolkaBridge: Distribute Token";

    using SafeERC20 for IERC20;

    function distributeToken(IERC20 token,
        address[] memory listUser,
        uint256[] memory listAmount
    ) public onlyOwner {
        for (uint256 i = 0; i < listUser.length; i++) {
            token.transfer(listUser[i], listAmount[i] * 1e18);
        }
    }

    function distributeToken(IERC20 token,address[] memory listUser, uint256 amount)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < listUser.length; i++) {
            token.transfer(listUser[i], amount * 1e18);
        }
    }

    function withdrawToken(IERC20 token) public {
     
        token.transfer(owner(), token.balanceOf(address(this)));
    }
 
    receive() external payable {}
}
