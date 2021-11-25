pragma solidity 0.7.6;

import "../dependencies/openzeppelin/contracts/SafeMath.sol";
import "../dependencies/openzeppelin/contracts/IERC20.sol";
import "../dependencies/openzeppelin/contracts/Ownable.sol";
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

interface IMultiFeeDistribution {
    function lockedBalances(address user) view external returns (uint256);
    function lockedSupply() external view returns (uint256);
}

contract ProtocolOwnedDEXLiquidity is Ownable {

    using SafeMath for uint256;

    IUniswapLPToken constant public lpToken = IUniswapLPToken(0x668AE94D0870230AC007a01B471D02b2c94DDcB9);
    IERC20 constant public gFTM = IERC20(0x39B3bd37208CBaDE74D0fcBDBb12D606295b430a);
    IMultiFeeDistribution constant public treasury = IMultiFeeDistribution(0x49c93a95dbcc9A6A4D8f77E59c038ce5020e82f8);

    struct UserRecord {
        uint256 nextClaimTime;
        uint256 claimCount;
        uint256 totalBoughtFTM;
    }

    mapping (address => UserRecord) public userData;

    uint public totalSoldFTM;
    uint public minBuyAmount;
    uint public minSuperPODLLock;
    uint public buyCooldown;
    uint public superPODLCooldown;
    uint public lockedBalanceMultiplier;

    event SoldFTM(
        address indexed buyer,
        uint256 amount
    );
    event AaaaaaahAndImSuperPODLiiiiing(
        address indexed podler,
        uint256 amount
    );

    constructor(
        uint256 _lockMultiplier,
        uint256 _minBuy,
        uint256 _minLock,
        uint256 _cooldown,
        uint256 _podlCooldown
    ) Ownable() {
        IChefIncentivesController chef = IChefIncentivesController(0x297FddC5c33Ef988dd03bd13e162aE084ea1fE57);
        chef.setClaimReceiver(address(this), address(treasury));
        setParams(_lockMultiplier, _minBuy, _minLock, _cooldown, _podlCooldown);
    }

    function setParams(
        uint256 _lockMultiplier,
        uint256 _minBuy,
        uint256 _minLock,
        uint256 _cooldown,
        uint256 _podlCooldown
    ) public onlyOwner {
        require(_minBuy >= 1e18);
        lockedBalanceMultiplier = _lockMultiplier;
        minBuyAmount = _minBuy;
        minSuperPODLLock = _minLock;
        buyCooldown = _cooldown;
        superPODLCooldown = _podlCooldown;
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

    function availableForUser(address _user) public view returns (uint256) {
        UserRecord storage u = userData[_user];
        if (u.nextClaimTime > block.timestamp) return 0;
        uint available = availableFTM();
        uint userLocked = treasury.lockedBalances(_user);
        uint totalLocked = treasury.lockedSupply();
        uint amount = available.mul(lockedBalanceMultiplier).mul(userLocked).div(totalLocked);
        if (amount > available) {
            return available;
        }
        return amount;
    }

    function lpTokensPerOneFTM() public view returns (uint256) {
        uint totalSupply = lpToken.totalSupply();
        (uint reserve0,,) = lpToken.getReserves();
        return totalSupply.mul(1e18).mul(45).div(reserve0).div(100);
    }

    function _buy(uint _amount, uint _cooldownTime) internal {
        require(_amount >= minBuyAmount, "Below min buy amount");
        uint lpAmount = _amount.mul(lpTokensPerOneFTM()).div(1e18);
        lpToken.transferFrom(msg.sender, address(this), lpAmount);
        gFTM.transfer(msg.sender, _amount);
        gFTM.transfer(address(treasury), _amount);

        UserRecord storage u = userData[msg.sender];
        u.nextClaimTime = block.timestamp.add(_cooldownTime);
        u.claimCount = u.claimCount.add(1);
        u.totalBoughtFTM = u.totalBoughtFTM.add(_amount);
        totalSoldFTM = totalSoldFTM.add(_amount);

        emit SoldFTM(msg.sender, _amount);
    }

    function buyFTM(uint256 _amount) public {
        require(_amount <= availableForUser(msg.sender), "Amount exceeds user limit");
        _buy(_amount, buyCooldown);
    }

    function superPODL(uint256 _amount) public {
        require(treasury.lockedBalances(msg.sender) >= minSuperPODLLock, "Need to lock GEIST!");
        _buy(_amount, superPODLCooldown);
        emit AaaaaaahAndImSuperPODLiiiiing(msg.sender, _amount);
    }
}
