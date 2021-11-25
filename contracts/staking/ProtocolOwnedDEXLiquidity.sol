pragma solidity 0.7.6;

import "../dependencies/openzeppelin/contracts/SafeMath.sol";
import "../dependencies/openzeppelin/contracts/IERC20.sol";
import "../interfaces/IChefIncentivesController.sol";

interface IJoePair {
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

    IJoePair constant public lpToken = IJoePair(0xac3F978714c613E768272c502a8912bC03DCf624);
    IERC20 constant public bAVAX = IERC20(0xB2AC04b71888E17Aa2c5102cf3d0215467D74100);
    address constant public treasury = 0xA867c1acA4B5F1E0a66cf7b1FE33525D57608854;

    uint public totalSoldAVAX;

    event SoldAVAX(
        address indexed buyer,
        uint256 amount
    );

    constructor() {
        IChefIncentivesController chef = IChefIncentivesController(0x2d867AE30400ffFaD9BeD8472c514c2d6b827F5f);
        chef.setClaimReceiver(address(this), treasury);
    }

    function protocolOwnedReserves() public view returns (uint256 blizz, uint256 wavax) {
        (uint reserve0, uint reserve1,) = lpToken.getReserves();
        uint balance = lpToken.balanceOf(address(this));
        uint totalSupply = lpToken.totalSupply();
        return (reserve0.mul(balance).div(totalSupply), reserve1.mul(balance).div(totalSupply));
    }

    function availableAVAX() public view returns (uint256) {
        return bAVAX.balanceOf(address(this)) / 2;
    }

    function lpTokensPerOneAVAX() public view returns (uint256) {
        uint totalSupply = lpToken.totalSupply();
        (,uint reserve1,) = lpToken.getReserves();
        return totalSupply.mul(1e18).mul(45).div(reserve1).div(100);
    }

    function buyAVAX(uint256 amount) public {
        require(amount >= 1e18, "Must purchase at least 1 WAVAX");
        uint lpAmount = amount.mul(lpTokensPerOneAVAX()).div(1e18);
        lpToken.transferFrom(msg.sender, address(this), lpAmount);
        bAVAX.transfer(msg.sender, amount);
        bAVAX.transfer(treasury, amount);
        totalSoldAVAX = totalSoldAVAX.add(amount);
        emit SoldAVAX(msg.sender, amount);
    }
}

