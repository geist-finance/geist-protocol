pragma solidity 0.7.6;

import "../dependencies/openzeppelin/contracts/SafeMath.sol";
import "../dependencies/openzeppelin/contracts/IERC20.sol";
import "../interfaces/IChefIncentivesController.sol";

interface IUniswapLPToken {
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}


contract ProtocolOwnedDEXLiquidity {

    using SafeMath for uint256;

    IUniswapLPToken constant public lpToken = IUniswapLPToken(0x668AE94D0870230AC007a01B471D02b2c94DDcB9);
    IERC20 constant public gFTM = IERC20(0x39B3bd37208CBaDE74D0fcBDBb12D606295b430a);
    address constant public treasury = 0x49c93a95dbcc9A6A4D8f77E59c038ce5020e82f8;

    uint public totalSoldFTM;

    event SoldFTM(
        address indexed buyer,
        uint256 amount
    );

    constructor() {
        IChefIncentivesController chef = IChefIncentivesController(0x297FddC5c33Ef988dd03bd13e162aE084ea1fE57);
        chef.setClaimReceiver(address(this), treasury);
    }

    function protocolOwnedReserves() public view returns (uint256 wftm, uint256 geist) {
        (uint reserve0, uint reserve1,) = lpToken.getReserves();
        uint balance = lpToken.balanceOf(address(this));
        uint totalSupply = lpToken.totalSupply();
        return (reserve0.mul(balance).div(totalSupply), reserve1.mul(balance).div(totalSupply));
    }

    function availableFTM() public view returns (uint256) {
        return gFTM.balanceOf(address(this)) / 2;
    }

    function lpTokensPerOneFTM() public view returns (uint256) {
        uint totalSupply = lpToken.totalSupply();
        (,uint reserve1,) = lpToken.getReserves();
        return totalSupply.mul(1e18).mul(45).div(reserve1).div(100);
    }

    function buyFTM(uint256 amount) public {
        require(amount >= 1e18, "Must purchase at least 1 WFTM");
        uint lpAmount = amount.mul(lpTokensPerOneFTM()).div(1e18);
        lpToken.transferFrom(msg.sender, address(this), lpAmount);
        gFTM.transfer(msg.sender, amount);
        gFTM.transfer(treasury, amount);
        totalSoldFTM = totalSoldFTM.add(amount);
        emit SoldFTM(msg.sender, amount);
    }
}

